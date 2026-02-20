//
//  ChatView.swift
//  Nostril
//
//  Created by Ben Nolan on 20/02/2026.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore
    
    @Query(sort: \Contact.lastMessageDate, order: .reverse) private var contacts: [Contact]
    
    private var myPubKey: String? {
        datastore?.npub
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let myPubKey {
                    ForEach(contacts.filter { $0.npub != myPubKey }) { contact in
                        NavigationLink {
                            MessageView(
                                otherUserPubKey: contact.npub
                            )
                        } label: {
                            ConversationRow(
                                pub: contact.npub,
                                myPubKey: myPubKey,
                                unreadCount: contact.unreadCount
                            )
                        }
                        .listRowInsets(.init(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } else {
                    ProgressView("Loading identity…")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chat")
        }
    }
}
    
    



private struct ConversationRow: View {
    let pub: String
    let myPubKey: String
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.blue)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(pub)
                    .font(.headline)
                    .lineLimit(1)

                RecentMessagePreview(
                    otherUserPubKey: pub,
                    myPubKey: myPubKey
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                ConversationTime(
                    otherUserPubKey: pub,
                    myPubKey: myPubKey
                )

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .padding(6)
                        .background(.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .contentShape(Rectangle())
    }
}

private struct RecentMessagePreview: View {
    @Query private var recentMessages: [Message]

    init(otherUserPubKey: String, myPubKey: String) {
        let me = myPubKey
        let other = otherUserPubKey
        
        let predicate = #Predicate<Message> { message in
            (message.authorPubKey == me && message.otherPubKey == other) ||
            (message.authorPubKey == other && message.otherPubKey == me)
        }
        
        _recentMessages = Query(
            filter: predicate,
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        Text(recentMessages.first?.content ?? "No messages yet")
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

private struct ConversationTime: View {
    @Query private var recentMessages: [Message]

    init(otherUserPubKey: String, myPubKey: String) {
        let me = myPubKey
        let other = otherUserPubKey
        
        let predicate = #Predicate<Message> { message in
            (message.authorPubKey == me && message.otherPubKey == other) ||
            (message.authorPubKey == other && message.otherPubKey == me)
        }
        
        _recentMessages = Query(
            filter: predicate,
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        if let date = recentMessages.first?.createdAt {
            Text(date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text("")
                .font(.caption)
        }
    }
}
