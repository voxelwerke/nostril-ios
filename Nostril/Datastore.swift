import Foundation
import SwiftData
import NostrSDK
import Security

final class Datastore: NSObject, EventCreating, RelayDelegate {
    
    private let modelContext: ModelContext
    private let myPubKey: String
    private let myKeypair: Keypair?
    private let relayPool: RelayPool

    // Track last AUTH event id for post-auth actions
    private var lastAuthEventId: String?

    // Default relays (restore if missing)
    private static let defaultRelayURLs: [String] = [
        "ws://192.168.1.28:8787",
    ]
    
    // Keep-alive timer
    private var keepAliveTimer: Timer?
    private let inboxSubscriptionId = "inbox-sub"

    init(modelContext: ModelContext, myPubKey: String) {
        print("🟡 [Datastore] INIT starting")

        self.modelContext = modelContext

        let nsec = KeychainStore.loadNsec()
        let kp: Keypair?
        if let nsec, !nsec.isEmpty {
            print("✅ [Datastore] Loaded nsec from Keychain")
            kp = Keypair(nsec: nsec)
        } else {
            print("⚠️ [Datastore] No private key found in Keychain")
            kp = nil
        }
        self.myKeypair = kp

        self.myPubKey = kp?.publicKey.npub ?? myPubKey
        print("🔑 [Datastore] Using pubkey: \(self.myPubKey)")

        self.relayPool = RelayPool(relays: [])

        super.init()

        self.relayPool.delegate = self

        // Start keep-alive timer
        startKeepAliveTimer()

        print("🟡 [Datastore] Connecting default relays...")
        self.connectDefaultRelays()
    }

    deinit {
        keepAliveTimer?.invalidate()
    }

    // MARK: - Helpers

    private func createAuthEvent(
        challenge: String,
        relayURL: URL,
        signedBy keypair: Keypair
    ) throws -> AuthenticationEvent {
        try AuthenticationEvent.Builder()
            .relayURL(relayURL)
            .challenge(challenge)
            .build(signedBy: keypair)
    }

    private func handleAuthChallenge(
        _ challenge: String,
        from relay: Relay,
        signedBy keypair: Keypair
    ) throws {
        let authEvent = try createAuthEvent(
            challenge: challenge,
            relayURL: relay.url,
            signedBy: keypair
        )

        print("🔐 [Datastore] Built AUTH event id=\(authEvent.id)")

        self.lastAuthEventId = authEvent.id

        do {
            try relay.authenticate(with: authEvent)
            print("✅ [Datastore] Authenticated")
        } catch {
            print("❌ [Datastore] Failed to authenticate: \(error)")
        }
    }

    // MARK: - Keep Alive & Subscriptions

    private func startKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.pingRelay()
        }
        RunLoop.main.add(keepAliveTimer!, forMode: .common)
        print("⏱️ [Datastore] Keep-alive timer started")
    }

    private func pingRelay() {
        guard let relay = relayPool.relays.first else {
            print("⏱️ [Datastore] No relay to ping")
            return
        }
        guard let keypair = myKeypair else {
            print("⏱️ [Datastore] No keypair for ping")
            return
        }
        // Use a small DM-to-self probe to keep the connection warm and trigger auth if needed
        let probeDM = DirectMessageEvent.Builder()
            .content("ping")
            .build(pubkey: keypair.publicKey.hex)
        do {
            let wrapToSelf = try giftWrap(
                withDirectMessageEvent: probeDM,
                toRecipient: keypair.publicKey,
                signedBy: keypair
            )
            try relay.publishEvent(wrapToSelf)
            print("📡 [Datastore] Keep-alive probe sent")
        } catch {
            print("⚠️ [Datastore] Keep-alive probe failed: \(error)")
        }
    }

    private func subscribeToInbox(on relay: Relay) {
        // TODO: Implement inbox subscription using NostrSDK's actual Filter/Subscription API.
        // Temporarily disabled to avoid compile errors due to unknown SDK types.
        print("🛰️ [Datastore] subscribeToInbox placeholder — implement with SDK-specific filters")
    }

    // MARK: - RelayDelegate

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        print("🔌 [RelayState] \(relay.url) -> \(state)")

        if state == .connected {
            print("🔄 Relay connected — subscribing and pinging")
            subscribeToInbox(on: relay)
            pingRelay()
        }
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        print("📥 [RelayResponse] From \(relay.url): \(response)")

        switch response {

        case .auth(let challenge):
            print("🔐 [Relay AUTH challenge] \(challenge)")

            guard let keypair = myKeypair else {
                print("❌ [Datastore] Cannot auth — no private key")
                return
            }

            do {
                try handleAuthChallenge(challenge, from: relay, signedBy: keypair)
            } catch {
                print("❌ [Datastore] Failed to handle AUTH challenge: \(error)")
            }

        case .ok(_, let success, let message):
            print("✅ [Relay OK] success=\(success) message=\(message.message)")
            // If AUTH just succeeded, we could flush any pending events here if you add a queue.

        case .notice(let message):
            print("📢 [Relay NOTICE] \(message)")

        case .closed(let subId, let message):
            print("❌ [Relay CLOSED] subId=\(subId) message=\(message.message)")

        default:
            break
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        print("📨 [RelayEvent] subscription=\(event.subscriptionId) kind=\(event.event.kind)")
    }

    // MARK: - Relays

    func connectDefaultRelays() {
        for urlString in Self.defaultRelayURLs {
            guard let url = URL(string: urlString) else {
                print("❌ [Datastore] Invalid relay URL: \(urlString)")
                continue
            }

            do {
                let relay = try Relay(url: url)
                print("➕ [Datastore] Adding relay \(url)")
                relayPool.add(relay: relay)
            } catch {
                print("❌ [Datastore] Failed to create relay for \(urlString): \(error)")
            }
        }

        print("🔌 [Datastore] Calling relayPool.connect()")
        relayPool.connect()
    }

    // MARK: - Nostr publish

    func publishDirectMessage(to recipientNpub: String, plaintext: String) throws {
        print("📤 [Datastore] Attempting to publish DM")
        print("   recipient npub: \(recipientNpub)")
        print("   plaintext: \(plaintext)")

        relayPool.relays.forEach {
            print("   - \($0.url) state=\($0.state)")
        }

        guard let senderKeypair = myKeypair else {
            print("❌ [Datastore] Missing private key")
            throw NSError(domain: "Datastore", code: 1)
        }

        guard let recipientPub = PublicKey(npub: recipientNpub) else {
            print("❌ [Datastore] Invalid recipient npub")
            throw NSError(domain: "Datastore", code: 2)
        }

        let directMessage = DirectMessageEvent.Builder()
            .content(plaintext)
            .build(pubkey: senderKeypair.publicKey.hex)

        print("✉️ [Datastore] Built DirectMessage id=\(directMessage.id)")

        let giftWrapForRecipient = try giftWrap(
            withDirectMessageEvent: directMessage,
            toRecipient: recipientPub,
            signedBy: senderKeypair
        )

        let giftWrapForSender = try giftWrap(
            withDirectMessageEvent: directMessage,
            toRecipient: senderKeypair.publicKey,
            signedBy: senderKeypair
        )

        guard let relay = relayPool.relays.first else {
            print("❌ [Datastore] No relay available")
            return
        }

        guard relay.state == .connected else {
            print("❌ [Datastore] Relay not connected")
            return
        }

        do {
            try relay.publishEvent(giftWrapForRecipient)
            try relay.publishEvent(giftWrapForSender)
            print("📡 [Datastore] DM published directly to relay")
        } catch {
            print("❌ [Datastore] Failed to publish DM: \(error)")
        }

        print("📡 [Datastore] Publish calls issued")
    }
}
