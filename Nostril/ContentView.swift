import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("myPubKey") private var myPubKey: String = "my-pubkey-placeholder"
    @Environment(\.modelContext) private var modelContext
    @State private var showSettings = false
    
    // Fixed: The Query needs to be properly attached to the property
    @Query(sort: \Contact.lastMessageDate, order: .reverse) private var contacts: [Contact]
    
    // ... inside ContentView struct
    private func debugPrintContacts() {
        print("--- 📱 Debug: Contact List (\(contacts.count) found) ---")
        for contact in contacts {
            print("""
            ID: \(contact.id)
            Pub: \(contact.npub)
            Unread: \(contact.unreadCount)
            -------------------------
            """)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(contacts) { contact in
                NavigationLink {
                    MessageView(
                        otherUserPubKey: contact.npub,
                        myPubKey: myPubKey
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
            .onChange(of: contacts) {
                debugPrintContacts()
            }
            .listStyle(.plain)
            .navigationTitle("Nostril")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    Button {
                        // Example: Add a new contact to test the query
                        let newContact = Contact(npub: "npub1-\(Int.random(in: 1000...9999))")
                        modelContext.insert(newContact)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                print("🟢 ContentView Appeared")
                print("Count is: \(contacts.count)")
                debugPrintContacts()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
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
                    .font(Font.headline)
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
        // Crucial: Use local constants to feed the Predicate
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
