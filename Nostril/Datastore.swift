import Foundation
import SwiftData
import NostrClient

@MainActor
final class Datastore: NSObject {
    // MARK: - Dependencies
    private let modelContext: ModelContext

    // MARK: - Nostr Client
    private let client = NostrClient()

    // Persisted identity
    private var keyPair: KeyPair?

    // Subscriptions tracking
    private var inboxSubscriptionId: String?

    // Default relays (restore if missing)
    private static let defaultRelayURLs: [String] = [
        "wss://relay.damus.io"
  
    ]
//    private static let defaultRelayURLs: [String] = [
//        "ws://192.168.1.28:8787"
//    ]

    // Keep-alive timer
    private var keepAliveTimer: Timer?

    // MARK: - Init / Deinit
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()

        // Attempt to load nsec from keychain and configure client
        Task { [weak self] in
            await self?.bootstrapIdentityAndRelays()
        }

        startKeepAliveTimer()
    }

    deinit {
        keepAliveTimer?.invalidate()
    }

    // MARK: - Bootstrap
    private func bootstrapIdentityAndRelays() async {
        // Load nsec from your existing keychain helper if available
        let nsec = KeychainStore.loadNsec()
        do {
            if let nsec, !nsec.isEmpty {
                try await client.setNsec(nsec)
                self.keyPair = try KeyPair(nsec: nsec)
                print("🔑 [Datastore] Loaded identity npub=\(self.keyPair?.npub ?? "-")")
            } else {
                // If no key, create one and store it
                let generated = try KeyPair()
                self.keyPair = generated
                try await client.setNsec(generated.nsec)
                KeychainStore.saveNsec(generated.nsec)
                print("🆕 [Datastore] Generated new identity npub=\(generated.npub)")
            }
        } catch {
            print("❌ [Datastore] Failed to configure identity: \(error)")
        }

        do {
            try await client.addRelays(Self.defaultRelayURLs)
            try await client.connect()
            print("🔌 [Datastore] Connected to default relays")

            // Subscribe to a basic inbox/global feed example
            try await subscribeToDMS(limit: 10)
        } catch {
            print("❌ [Datastore] Relay setup/connect failed: \(error)")
        }
    }

    // MARK: - Keep Alive
    private func startKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { await self?.sendKeepAliveNote() }
        }
        if let timer = keepAliveTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        print("⏱️ [Datastore] Keep-alive timer started")
    }

    private func sendKeepAliveNote() async {
        guard let _ = keyPair else { return }
        do {
            let event = try await client.publishTextNote(content: "ping")
            print("📡 [Datastore] Keep-alive note id=\(event.id)")
        } catch {
            print("⚠️ [Datastore] Keep-alive failed: \(error)")
        }
    }

    // MARK: - Public API (re-implemented)

    func connectDefaultRelays() {
        Task {
            do {
                try await client.addRelays(Self.defaultRelayURLs)
                try await client.connect()
                print("🔌 [Datastore] connectDefaultRelays -> connected")
            } catch {
                print("❌ [Datastore] connectDefaultRelays failed: \(error)")
            }
        }
    }

    func publishDirectMessage(to recipientNpub: String, plaintext: String) throws {
        Task {
            do {
                // Resolve recipient hex pubkey from npub
                let recipient = try PublicKey(npub: recipientNpub)
                let recipientHex = recipient.hex

                // Ensure we have our key pair
                guard let kp = keyPair else {
                    throw NSError(domain: "Datastore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing identity"])
                }

                // Build a sealed DM (gift-wrapped rumor -> kind 1059)
                let builder = DirectMessageBuilder(keyPair: kp)
                let dmEvent = try builder.createMessage(
                    content: plaintext,
                    to: recipientHex
                )

                // Publish the sealed DM
                try await client.publish(dmEvent)
                print("📤 [Datastore] Sealed DM (1059) published id=\(dmEvent.id) to p=\(recipientNpub)…")
            } catch {
                print("❌ [Datastore] Failed to publish sealed DM: \(error)")
            }
        }
    }

    // MARK: - Subscriptions
    private func subscribeToDMS(limit: Int) async throws {
        // Subscribe to DMs: rumor (14) and sealed/gift-wrapped (1059)
        guard let myself = keyPair?.publicKeyHex else {
            throw NSError(domain: "Datastore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing identity for DM subscription"])
        }

        // Prefer filtering by p-tag references to ourselves if supported by Filter
        let subId = try await client.subscribe(
            filters: [Filter(kinds: [14, 1059], pubkeyReferences: [myself])]
        ) { event in
            print("📥 [DM] kind=\(event.kind) id=\(event.id.prefix(16))… content=\(event.content.prefix(64))")
        }

        self.inboxSubscriptionId = subId
        print("🛰️ [Datastore] Subscribed to DMs (kinds 14,1059) subId=\(subId)")
    }
}

