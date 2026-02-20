import Foundation
import SwiftData

@Model
final class Message {
    /// Nostr event ID (hex) — used as the database identity
    @Attribute(.unique) var id: String
    
    var createdAt: Date
    var content: String
    var sender: String
    var recipient: String
    var chatKey: String

    init(
        id: String,
        createdAt: Date = Date(),
        content: String,
        sender: String,
        recipient: String,
        chatKey: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.content = content
        self.sender = sender
        self.recipient = recipient
        self.chatKey = chatKey
    }
}
