//
//  Contact.swift
//  Nostril
//
//  Created by Ben Nolan on 20/02/2026.
//


import Foundation
import SwiftData

@Model
final class Contact {
    @Attribute(.unique) var npub: String
    var name: String?
    var lastMessageDate: Date
    var unreadCount: Int

    init(
        npub: String,
        name: String? = nil,
        lastMessageDate: Date = .now,
        unreadCount: Int = 0
    ) {
        self.npub = npub
        self.name = name
        self.lastMessageDate = lastMessageDate
        self.unreadCount = unreadCount
    }
}
