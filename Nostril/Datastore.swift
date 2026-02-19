import Foundation
import SwiftData
import NostrSDK
import Security

final class Datastore: NSObject, EventCreating, RelayDelegate {
    
    private let modelContext: ModelContext
    private let myPubKey: String
    private let myKeypair: Keypair?
    private let relayPool: RelayPool

    private static let defaultRelayURLs: [String] = [
        "ws://192.168.1.28:8787",
    ]

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

        print("🟡 [Datastore] Connecting default relays...")
        self.connectDefaultRelays()
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

        do {
            try relay.authenticate(with: authEvent)
            print("✅ [Datastore] AUTH event published via publishEvent()")
        } catch {
            print("❌ [Datastore] Failed to publish AUTH event: \(error)")
        }
        
        
        print("✅ [Datastore] AUTH request sent via relay.send()")
    }

    // MARK: - RelayDelegate

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        print("🔌 [RelayState] \(relay.url) -> \(state)")
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

        case .ok(let eventId, let success, let message):
            print("✅ [Relay OK] eventId=\(eventId) success=\(success) message=\(message.message)")

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

        relayPool.publishEvent(giftWrapForRecipient)
        relayPool.publishEvent(giftWrapForSender)

        print("📡 [Datastore] Publish calls issued")
    }
}
