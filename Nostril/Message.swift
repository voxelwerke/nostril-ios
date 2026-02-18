import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var content: String
    var authorPubKey: String
    var otherPubKey: String
    var eventID: String

    init(id: UUID = UUID(), createdAt: Date = Date(), content: String, authorPubKey: String, otherPubKey: String, eventID: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.content = content
        self.authorPubKey = authorPubKey
        self.otherPubKey = otherPubKey
        self.eventID = eventID
    }
}
