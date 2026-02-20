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

    // MARK: - Bootstrap
    private func bootstrapIdentityAndRelays() async {
        let nsec = KeychainStore.loadNsec()
        do {
            if let nsec, !nsec.isEmpty {
                try await client.setNsec(nsec)
                self.keyPair = try KeyPair(nsec: nsec)
                print("🔑 Loaded identity npub=\(self.keyPair?.npub ?? "-")")
            } else {
                let generated = try KeyPair()
                self.keyPair = generated
                try await client.setNsec(generated.nsec)
                KeychainStore.saveNsec(generated.nsec)
                print("🆕 Generated new identity npub=\(generated.npub)")
            }
        } catch {
            print("❌ Failed to configure identity: \(error)")
        }

        do {
            try await client.addRelays(Self.defaultRelayURLs)
            try await client.connect()
            print("🔌 Connected to relays")
            try await subscribeToDMS(limit: 50)
        } catch {
            print("❌ Relay setup/connect failed: \(error)")
        }
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
                _ = try await client.sendDirectMessage(plaintext, to: recipient.hex)
                print("📤 DM published to \(recipientNpub)")
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

    private func subscribeToDMS(limit: Int) async throws {
        let subId = try await client.subscribeToDirectMessages(limit: limit) { [weak self] giftWrap in
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
                }
            }
        }

        self.inboxSubscriptionId = subId
        print("🛰️ Subscribed to DMs subId=\(subId)")
    }
}

