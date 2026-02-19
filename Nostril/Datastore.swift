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
        "wss://relay.damus.io",
        "wss://nos.lol"
    ]

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
            try await subscribeToGlobal(limit: 10)
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
        // Re-implemented using NostrClient primitives
        Task {
            do {
                // Ensure identity is configured
                if keyPair == nil {
                    try await bootstrapIdentityAndRelays()
                }

                // Build and publish a DM as a text note with p-tag (depending on library support)
                // If NostrClient exposes a dedicated DM API in future, switch to it.
                let recipient = try PublicKey(npub: recipientNpub)

                // Use EventSigner for explicit control
                guard let kp = keyPair else { throw NSError(domain: "Datastore", code: 1) }
                let signer = EventSigner(keyPair: kp)
                let dm = try signer.signTextNote(
                    content: plaintext,
                    tags: [["p", recipient.hex]]
                )

                try await client.publish(dm)
                print("📤 [Datastore] DM published id=\(dm.id) to p=\(recipient.hex.prefix(16))…")
            } catch {
                print("❌ [Datastore] Failed to publish DM: \(error)")
            }
        }
    }

    // MARK: - Subscriptions
    private func subscribeToGlobal(limit: Int) async throws {
        // Store subscription id to allow later unsubscribe if needed
        let subId = try await client.subscribeToGlobalFeed(limit: limit) { event in
            print("📥 [Global] \(event.kind) id=\(event.id.prefix(16))… content=\(event.content.prefix(64))")
        }
        self.inboxSubscriptionId = subId
        print("🛰️ [Datastore] Subscribed to global feed subId=\(subId)")
    }
}

