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

    public var npub: String?

    // Subscriptions tracking
    private var inboxSubscriptionId: String?
    private var dmRefreshTask: Task<Void, Never>?

    // Default relays
    private static let defaultRelayURLs: [String] = [
        "wss://relay.damus.io"
    ]

    // MARK: - Init
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()

        Task { [weak self] in
            await self?.bootstrapIdentityAndRelays()
        }
    }

    deinit {
        dmRefreshTask?.cancel()
    }

    // MARK: - Bootstrap
    private func bootstrapIdentityAndRelays() async {
        let nsec = KeychainStore.loadNsec()
        do {
            try await client.setNsec(nsec!)
            self.keyPair = try KeyPair(nsec: nsec!)
            self.npub = self.keyPair!.npub
            print("🔑 Loaded identity npub=\(self.keyPair?.npub ?? "-")")
        } catch {
            print("❌ Failed to configure identity: \(error)")
        }

        do {
            try await client.addRelays(Self.defaultRelayURLs)
            try await client.connect()
            print("🔌 Connected to relays")

            restartDMSubscriptionLoop()

        } catch {
            print("❌ Relay setup/connect failed: \(error)")
        }
    }

    // MARK: - DM Subscription Loop

    private func restartDMSubscriptionLoop() {
        // Cancel previous loop
        dmRefreshTask?.cancel()

        dmRefreshTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await self.resubscribeToDMs()
                } catch {
                    print("❌ Resubscribe failed: \(error)")
                }

                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func resubscribeToDMs() async throws {
        // Kill previous subscription if it exists
        if let subId = inboxSubscriptionId {
            await client.unsubscribe(subscriptionId: subId)
            inboxSubscriptionId = nil
            print("♻️ Unsubscribed previous DM subscription")
        }

        let subId = try await subscribeToDMS(limit: 5)
        inboxSubscriptionId = subId
        print("🛰️ Subscribed to DMs subId=\(subId)")
    }

    // MARK: - Public API

    func connectDefaultRelays() {
        Task {
            do {
                try await client.addRelays(Self.defaultRelayURLs)
                try await client.connect()
                print("🔌 connectDefaultRelays -> connected")
            } catch {
                print("❌ connectDefaultRelays failed: \(error)")
            }
        }
    }

    func publishDirectMessage(to recipientNpub: String, plaintext: String) throws {
        Task {
            do {
                let recipient = try PublicKey(npub: recipientNpub)
                let event = try await client.sendDirectMessage(plaintext, to: recipient.hex)

                await MainActor.run {
                    self.insertMessageIfNeeded(
                        id: event.id,
                        createdAt: Date(),
                        content: plaintext,
                        author: self.keyPair?.publicKeyHex ?? "",
                        other: recipient.hex
                    )
                }

                print("📤 DM published and saved locally")
            } catch {
                print("❌ Failed to publish DM: \(error)")
            }
        }
    }

    // MARK: - DM Parsing

    private func getKeyPair() throws -> KeyPair {
        guard let keyPair else {
            throw NostrError.signingFailed
        }
        return keyPair
    }

    public func parseDirectMessage(_ giftWrap: Event) throws -> DirectMessage {
        let parser = DirectMessageParser(keyPair: try getKeyPair())
        return try parser.parse(giftWrap)
    }

    // MARK: - Insert If Needed

    private func insertMessageIfNeeded(
        id: String,
        createdAt: Date,
        content: String,
        author: String,
        other: String
    ) {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.id == id }
        )

        updateContact(hexPubkey: author, messageDate: createdAt)
        updateContact(hexPubkey: other, messageDate: createdAt)

        if let existing = try? modelContext.fetch(descriptor),
           !existing.isEmpty {
            return
        }

        let message = Message(
            id: id,
            createdAt: createdAt,
            content: content,
            authorPubKey: author,
            otherPubKey: other
        )

        modelContext.insert(message)
        try? modelContext.save()
    }

    private func updateContact(hexPubkey: String, messageDate: Date) {
        guard let npub = try? PublicKey(hex: hexPubkey).npub else {
            print("Could not get npub from hex: \(hexPubkey)")
            return
        }

        let descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate { $0.npub == npub }
        )

        if let existing = try? modelContext.fetch(descriptor),
           let contact = existing.first {

            contact.lastMessageDate = messageDate
            contact.unreadCount += 1
            print("Increased unread count")

        } else {

            let contact = Contact(
                npub: npub,
                lastMessageDate: messageDate,
                unreadCount: 1
            )

            modelContext.insert(contact)
            print("Inserted new contact")
        }
    }

    // MARK: - Subscriptions

    private func subscribeToDMS(limit: Int) async throws -> String {
        try await client.subscribeToDirectMessages(limit: limit) { [weak self] giftWrap in
            guard let self else { return }

            Task { [weak self] in
                guard let self else { return }

                print("📥 giftWrap received id=\(giftWrap.id.prefix(16))…")

                await MainActor.run {
                    do {
                        let dm = try self.parseDirectMessage(giftWrap)

                        self.insertMessageIfNeeded(
                            id: giftWrap.id,
                            createdAt: dm.createdAt,
                            content: dm.content,
                            author: dm.senderPubkey,
                            other: dm.recipientPubkey
                        )

                        print("💾 Saved DM \(giftWrap.id.prefix(16))…")

                    } catch let error as NostrError where error == .hmacVerificationFailed {

                        self.insertMessageIfNeeded(
                            id: giftWrap.id,
                            createdAt: Date(),
                            content: "unable to decode",
                            author: giftWrap.pubkey,
                            other: self.keyPair?.publicKeyHex ?? ""
                        )

                        print("⚠️ HMAC failed — inserted placeholder")

                    } catch {
                        print("❌ Failed to parse/save DM: \(error)")
                    }

                    try? self.modelContext.save()
                }
            }
        }
    }
}

