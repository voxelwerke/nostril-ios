import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var myPubKey: String = "my-pubkey-placeholder"
    @State private var contacts: [String] = ["npub1-alice", "npub1-bob", "npub1-carol"]

    var body: some View {
        NavigationStack {
            List(contacts, id: \.self) { pub in
                NavigationLink {
                    MessageView(otherUserPubKey: pub, myPubKey: myPubKey)
                } label: {
                    ConversationRow(pub: pub, myPubKey: myPubKey)
                }
                .listRowInsets(.init(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            .listStyle(.plain)
            .navigationTitle("Nostril")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        contacts.append("npub1-\(Int.random(in: 1000...9999))")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct ConversationRow: View {
    let pub: String
    let myPubKey: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.blue)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(pub)
                    .font(.headline)
                    .lineLimit(1)

                RecentMessagePreview(otherUserPubKey: pub, myPubKey: myPubKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            ConversationTime(otherUserPubKey: pub, myPubKey: myPubKey)
        }
        .contentShape(Rectangle())
    }
}

private struct RecentMessagePreview: View {
    let otherUserPubKey: String
    let myPubKey: String

    @Query private var recentMessages: [Message]

    init(otherUserPubKey: String, myPubKey: String) {
        self.otherUserPubKey = otherUserPubKey
        self.myPubKey = myPubKey
        let me = myPubKey
        let other = otherUserPubKey
        _recentMessages = Query(
            filter: #Predicate<Message> { message in
                ((message.authorPubKey == me) && (message.otherPubKey == other)) ||
                ((message.authorPubKey == other) && (message.otherPubKey == me))
            },
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        Text(recentMessages.first?.content ?? " ")
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

private struct ConversationTime: View {
    let otherUserPubKey: String
    let myPubKey: String

    @Query private var recentMessages: [Message]

    init(otherUserPubKey: String, myPubKey: String) {
        self.otherUserPubKey = otherUserPubKey
        self.myPubKey = myPubKey
        let me = myPubKey
        let other = otherUserPubKey
        _recentMessages = Query(
            filter: #Predicate<Message> { message in
                ((message.authorPubKey == me) && (message.otherPubKey == other)) ||
                ((message.authorPubKey == other) && (message.otherPubKey == me))
            },
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
            Text(" ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
