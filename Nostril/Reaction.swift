//
//  Reaction.swift
//  Nostril
//
//  Created by Ben Nolan on 20/02/2026.
//


import Foundation
import SwiftData

@Model
final class Reaction {
    @Attribute(.unique) var id: String

    var targetMessageId: String
    var emoji: String

    var sender: String
    var recipient: String

    var createdAt: Date

    init(
        id: String,
        targetMessageId: String,
        emoji: String,
        sender: String,
        recipient: String,
        createdAt: Date
    ) {
        self.id = id
        self.targetMessageId = targetMessageId
        self.emoji = emoji
        self.sender = sender
        self.recipient = recipient
        self.createdAt = createdAt
    }
}
