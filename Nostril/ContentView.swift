import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore
    
    @State private var showSettings = false
    @State private var selectedTab: String = "Chat" // Track the selection
    
    @Query(sort: \Contact.lastMessageDate, order: .reverse) private var contacts: [Contact]
    
    private var myPubKey: String? {
        datastore?.npub
    }
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                .navigationTitle("Nostril")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                        Button {
//                            let newContact = Contact(npub: "npub1-\(Int.random(in: 1000...9999))")
//                            modelContext.insert(newContact)
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
        }
        
        // The Floating Photos-style Bar
                    HStack(spacing: 15) {
                        // Left Arrow Button
//                        Button(action: { /* Action */ }) {
//                            Image(systemName: "arrow.up.arrow.down")
//                                .font(.system(size: 14, weight: .bold))
//                        }
//                        .buttonStyle(CircleButtonStyle())

                        // Main Pill
                        HStack(spacing: 0) {
                            TabButton(title: "Chat", selection: $selectedTab)
                            TabButton(title: "Space", selection: $selectedTab)
                            TabButton(title: "Explore", selection: $selectedTab)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

                        // Close/X Button
//                        Button(action: { /* Action */ }) {
//                            Image(systemName: "xmark")
//                                .font(.system(size: 14, weight: .bold))
//                        }
//                        .buttonStyle(CircleButtonStyle())
                    }
                    .padding(.bottom, 20) // Floating distance from bottom
    }
    
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Button(action: { selection = title }) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(selection == title ? AnyView(Capsule().fill(.white.opacity(0.2))) : AnyView(EmptyView()))
                .foregroundColor(.primary)
        }
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
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
