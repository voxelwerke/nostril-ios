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
        "ws://localhost:8787",
    ]

    init(modelContext: ModelContext, myPubKey: String) {
        self.modelContext = modelContext

        let nsec = Self.loadNsecFromKeychain()
        let kp: Keypair?
        if let nsec, !nsec.isEmpty {
            kp = Keypair(nsec: nsec)
        } else {
            kp = nil
        }
        self.myKeypair = kp

        self.myPubKey = kp?.publicKey.npub ?? myPubKey
        
        
        self.relayPool = RelayPool(relays: [])

        super.init()

        self.relayPool.delegate = self

        self.connectDefaultRelays()
    }

    func messagesFetchDescriptor(for otherPubKey: String) -> FetchDescriptor<Message> {
        let me = myPubKey
        let other = otherPubKey
        return FetchDescriptor<Message>(
            predicate: #Predicate { message in
                ((message.authorPubKey == me) && (message.otherPubKey == other)) ||
                ((message.authorPubKey == other) && (message.otherPubKey == me))
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
    }

    // MARK: - RelayDelegate

    func relay(_ relay: Relay, didReceiveAuthChallenge challenge: String) {
        guard let keypair = myKeypair else {
            print("[Datastore] Cannot auth — no private key")
            return
        }

        do {
            let authEvent = try createAuthEvent(challenge: challenge, relayURL: relay.url, signedBy: keypair)
            try relay.publishEvent(authEvent)
            print("[Datastore] Sent AUTH event to \(relay.url)")
        } catch {
            print("[Datastore] Failed to respond to AUTH challenge: \(error)")
        }
    }
    
    func relayStateDidChange(_ relay: NostrSDK.Relay, state: NostrSDK.Relay.State) {
        
    }
    
    func relay(_ relay: NostrSDK.Relay, didReceive response: NostrSDK.RelayResponse) {
//        <#code#>
    }
    
    func relay(_ relay: NostrSDK.Relay, didReceive event: NostrSDK.RelayEvent) {
//        <#code#>
    }

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
    
    
    func myNpub() -> String {
        myPubKey
    }

    func hasPrivateKey() -> Bool {
        myKeypair != nil
    }

    // MARK: - Relays

    func connectDefaultRelays() {
        for urlString in Self.defaultRelayURLs {
            guard let url = URL(string: urlString) else {
                print("[Datastore] Invalid relay URL: \(urlString)")
                continue
            }

            do {
                let relay = try Relay(url: url)
                relayPool.add(relay: relay)
            } catch {
                print("[Datastore] Failed to create relay for \(urlString): \(error)")
            }
        }

        do {
            try relayPool.connect()
        } catch {
            print("[Datastore] Failed to connect relays: \(error)")
        }
    }

    func connectRelays(_ relayURLs: [String]) {
        for urlString in relayURLs {
            guard let url = URL(string: urlString) else {
                print("[Datastore] Invalid relay URL: \(urlString)")
                continue
            }

            do {
                let relay = try Relay(url: url)
                relayPool.add(relay: relay)
            } catch {
                print("[Datastore] Failed to create relay for \(urlString): \(error)")
            }
        }

        do {
            try relayPool.connect()
        } catch {
            print("[Datastore] Failed to connect relays: \(error)")
        }
    }

    // MARK: - Nostr publish

    func publishDirectMessage(to recipientNpub: String, plaintext: String) throws {
        guard let senderKeypair = myKeypair else {
            throw NSError(
                domain: "Datastore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing private key in Keychain"]
            )
        }

        guard let recipientPub = PublicKey(npub: recipientNpub) else {
            throw NSError(
                domain: "Datastore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid recipient npub"]
            )
        }

        let directMessage = DirectMessageEvent.Builder()
            .content(plaintext)
            .build(pubkey: senderKeypair.publicKey.hex)
        
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
    }

    // MARK: - Keychain

    private static func loadNsecFromKeychain() -> String? {
        let account = "nostr_private_key_nsec"
        let service = Bundle.main.bundleIdentifier ?? "Nostril"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func postMessage(content: String, authorPubKey: String, otherPubKey: String) throws -> Message {
        let message = Message(content: content, authorPubKey: authorPubKey, otherPubKey: otherPubKey)
        modelContext.insert(message)

        do {
            try modelContext.save()

            if hasPrivateKey(), otherPubKey.contains("npub") {
                do {
                    try publishDirectMessage(to: otherPubKey, plaintext: content)
                } catch {
                    print("[Datastore] Relay publish failed (non-fatal): \(error)")
                }
            }
        } catch {
            print("[Datastore] Error saving message: \(error)")
            throw error
        }

        return message
    }

    func deleteMessage(_ message: Message) throws {
        modelContext.delete(message)
        try modelContext.save()
    }

    func updateMessage(_ message: Message, newContent: String) throws {
        message.content = newContent
        try modelContext.save()
    }

    static func previewContainer(inMemory: Bool = true) throws -> ModelContainer {
        let schema = Schema([Message.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
