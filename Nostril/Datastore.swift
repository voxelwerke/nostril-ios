import Foundation
import SwiftData
import NostrClient

@MainActor
final class Datastore: NSObject {
    // MARK: - Dependencies
    private let modelContext: ModelContext

    // MARK: - Nostr Client
    private let client = NostrClient()

    private var keyPair: KeyPair?

    public var npub: String?
    public var hex: String?

    private var inboxSubscriptionId: String?
    private var dmRefreshTask: Task<Void, Never>?

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
        guard let nsec = KeychainStore.loadNsec() else { return }

        do {
            try await client.setNsec(nsec)
            self.keyPair = try KeyPair(nsec: nsec)
            self.npub = keyPair?.npub
            self.hex = keyPair?.publicKeyHex
            print("🔑 Loaded identity \(self.npub ?? "")")
        } catch {
            print("❌ Identity setup failed: \(error)")
        }

        do {
            try await client.addRelays(Self.defaultRelayURLs)
            try await client.connect()
            restartDMSubscriptionLoop()
        } catch {
            print("❌ Relay connection failed: \(error)")
        }
    }

    // MARK: - Public DM Send

    func publishDirectMessage(to recipientNpub: String, plaintext: String) {
        Task {
            do {
                let recipient = try PublicKey(npub: recipientNpub)
                let event = try await client.sendDirectMessage(
                    plaintext,
                    to: recipient.hex
                )

                self.insertMessage(
                    id: event.id,
                    createdAt: Date(),
                    content: plaintext,
                    sender: self.keyPair!.publicKeyHex,
                    recipient: recipient.hex
                )

                print("📤 DM sent")
            } catch {
                print("❌ DM send failed: \(error)")
            }
        }
    }

    // MARK: - Tapbacks

    func sendReaction(
        emoji: String,
        to recipientHex: String,
        reactingTo messageId: String
    ) {
        Task {
            guard let keyPair else { return }

            let senderHex = keyPair.publicKeyHex

            let descriptor = FetchDescriptor<Reaction>(
                predicate: #Predicate {
                    $0.targetMessageId == messageId &&
                    $0.sender == senderHex
                }
            )

            let existing = try? modelContext.fetch(descriptor)
            let existingReaction = existing?.first

            if let existingReaction, existingReaction.emoji == emoji {
                modelContext.delete(existingReaction)
                try? modelContext.save()
                print("↩️ Tapback removed")
                return
            }

            if let existingReaction {
                modelContext.delete(existingReaction)
            }

            do {
                let payload = EncryptedReactionPayload(
                    emoji: emoji,
                    targetEventId: messageId,
                    recipientPubkey: recipientHex
                )

                let data = try JSONEncoder().encode(payload)
                let json = String(decoding: data, as: UTF8.self)

                let giftWrap = try await client.sendDirectMessage(
                    json,
                    to: recipientHex
                )

                let reaction = Reaction(
                    id: giftWrap.id,
                    targetMessageId: messageId,
                    emoji: emoji,
                    sender: senderHex,
                    recipient: recipientHex,
                    createdAt: Date()
                )

                modelContext.insert(reaction)
                try? modelContext.save()

                print("✅ Tapback sent")
            } catch {
                print("❌ Tapback failed: \(error)")
            }
        }
    }

    // MARK: - Subscription Loop

    private func restartDMSubscriptionLoop() {
        dmRefreshTask?.cancel()

        dmRefreshTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await self.resubscribeToDMs()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func resubscribeToDMs() async throws {
        if let subId = inboxSubscriptionId {
            await client.unsubscribe(subscriptionId: subId)
        }

        inboxSubscriptionId = try await subscribeToDMS(limit: 50)
    }

    // MARK: - Subscribe To DMs

    private func subscribeToDMS(limit: Int) async throws -> String {
        try await client.subscribeToDirectMessages(limit: limit) { [weak self] giftWrap in
            guard let self else { return }

            Task {
                do {
                    // ✅ Call actor-isolated method correctly
                    let dm = try await self.client.parseDirectMessage(giftWrap)

                    await MainActor.run {

                        // ✅ Reaction decode first
                        if let data = dm.content.data(using: .utf8),
                           let payload = try? JSONDecoder().decode(EncryptedReactionPayload.self, from: data),
                           payload.kind == 7,
                           let targetId = payload.targetEventId {

                            self.handleIncomingReaction(
                                giftWrap: giftWrap,
                                dm: dm,
                                payload: payload,
                                targetId: targetId
                            )
                            return
                        }

                        // ✅ Normal DM
                        self.insertMessage(
                            id: giftWrap.id,
                            createdAt: dm.createdAt,
                            content: dm.content,
                            sender: dm.senderPubkey,
                            recipient: dm.recipientPubkey
                        )
                    }

                } catch {
                    print("❌ DM parse failed: \(error)")
                }
            }
        }
    }

    // MARK: - Incoming Tapback Handler

    private func handleIncomingReaction(
        giftWrap: Event,
        dm: DirectMessage,
        payload: EncryptedReactionPayload,
        targetId: String
    ) {
        let senderHex = dm.senderPubkey

        let descriptor = FetchDescriptor<Reaction>(
            predicate: #Predicate {
                $0.targetMessageId == targetId &&
                $0.sender == senderHex
            }
        )

        let existing = try? modelContext.fetch(descriptor)
        let existingReaction = existing?.first

        if let existingReaction,
           existingReaction.emoji == payload.content {

            modelContext.delete(existingReaction)
            try? modelContext.save()
            print("↩️ Remote tapback removed")
            return
        }

        if let existingReaction {
            modelContext.delete(existingReaction)
        }

        let reaction = Reaction(
            id: giftWrap.id,
            targetMessageId: targetId,
            emoji: payload.content,
            sender: senderHex,
            recipient: dm.recipientPubkey,
            createdAt: dm.createdAt
        )

        modelContext.insert(reaction)
        try? modelContext.save()

        print("❤️ Remote tapback applied")
    }

    // MARK: - Insert Message

    private func insertMessage(
        id: String,
        createdAt: Date,
        content: String,
        sender: String,
        recipient: String
    ) {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try? modelContext.fetch(descriptor),
           !existing.isEmpty {
            return
        }

        let chatKey = sender == keyPair?.publicKeyHex ? recipient : sender

        let message = Message(
            id: id,
            createdAt: createdAt,
            content: content,
            sender: sender,
            recipient: recipient,
            chatKey: chatKey
        )

        modelContext.insert(message)
        try? modelContext.save()
    }
}
