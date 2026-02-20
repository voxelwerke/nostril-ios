//
//  EncryptedReactionPayload.swift
//  Nostril
//
//  Created by Ben Nolan on 20/02/2026.
//


import Foundation

/// Typed encrypted reaction payload (kind 7) used inside NIP-17 chats
struct EncryptedReactionPayload: Codable {
    let kind: Int
    let content: String
    let tags: [[String]]

    init(
        emoji: String,
        targetEventId: String,
        recipientPubkey: String
    ) {
        self.kind = 7
        self.content = emoji
        self.tags = [
            ["p", recipientPubkey],
            ["e", targetEventId]
        ]
    }

    var targetEventId: String? {
        tags.first(where: { $0.first == "e" })?[safe: 1]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
