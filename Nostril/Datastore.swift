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


    // MARK: - Init / Deinit
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()

        // Attempt to load nsec from keychain and configure client
        Task { [weak self] in
            await self?.bootstrapIdentityAndRelays()
        }
    }

    // MARK: - Bootstrap
    private func bootstrapIdentityAndRelays() async {
        // Load nsec from your existing keychain helper if available
        let nsec = KeychainStore.loadNsec()
        do {
            if let nsec, !nsec.isEmpty {
                try await client.setNsec(nsec)
                print("nsec: \(nsec)")
                
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
            try await subscribeToDMS(limit: 50)
        } catch {
            print("❌ [Datastore] Relay setup/connect failed: \(error)")
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

                // Publish a sealed DM (gift-wrapped rumor -> kind 1059) via NostrClient
                _ = try await client.sendDirectMessage(plaintext, to: recipientHex)
                print("📤 [Datastore] Sealed DM (1059) published to p=\(recipientNpub)…")
            } catch {
                print("❌ [Datastore] Failed to publish sealed DM: \(error)")
            }
        }
    }

    
    /// Helper to get the keypair from the signer
    private func getKeyPair() throws -> KeyPair {
        return self.keyPair!
    }
    
    
    /// Parses a received gift-wrapped direct message
    /// - Parameter giftWrap: The gift-wrapped event
    /// - Returns: The parsed DirectMessage
    public func parseDirectMessage(_ giftWrap: Event) throws -> DirectMessage {
        guard let keyPair = try? getKeyPair() else {
            throw NostrError.signingFailed
        }

        let parser = DirectMessageParser(keyPair: keyPair)
        return try parser.parse(giftWrap)
    }
    
    // MARK: - Subscriptions
    private func subscribeToDMS(limit: Int) async throws {
        // Subscribe to gift-wrapped direct messages addressed to us, then parse to plaintext and persist
        let subId = try await client.subscribeToDirectMessages(limit: limit) { [weak self] giftWrap in
            guard let self else { return }
            // Perform async work inside a Task since the API expects a sync callback
            Task { [weak self] in
                guard let self else { return }
                print("📥 [DM] giftWrap recieved kind=\(giftWrap.kind) id=\(giftWrap.id.prefix(16))…")

                // Hop to the main actor to call main-actor isolated APIs and touch modelContext
                await MainActor.run {
                    do {
                        let dm = try self.parseDirectMessage(giftWrap)

                        let author = dm.senderPubkey
                        let other = dm.recipientPubkey

                        let message = Message(
                            createdAt: dm.createdAt,
                            content: dm.content,
                            authorPubKey: author,
                            otherPubKey: other,
                            eventID: giftWrap.id
                        )
                        self.modelContext.insert(message)
                        try self.modelContext.save()
                        print("💾 [Datastore] Saved DM eventID=\(giftWrap.id.prefix(16))…")
                    } catch {
                        print("❌ [Datastore] Failed to parse/save DM: \(error)")
                    }
                }
            }
        }

        self.inboxSubscriptionId = subId
        print("🛰️ [Datastore] Subscribed to DMs via NostrClient subId=\(subId)")
    }
}

