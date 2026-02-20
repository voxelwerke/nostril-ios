import Foundation
import SwiftData

@Model
final class Message {
    /// Nostr event ID (hex) — used as the database identity
    @Attribute(.unique) var id: String
    
    var createdAt: Date
    var content: String
    var authorPubKey: String
    var otherPubKey: String

    init(
        id: String,
        createdAt: Date = Date(),
        content: String,
        authorPubKey: String,
        otherPubKey: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.content = content
        self.authorPubKey = authorPubKey
        self.otherPubKey = otherPubKey
    }
}
