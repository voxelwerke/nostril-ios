import SwiftUI
import SwiftData
import NostrClient

struct MessageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore

    let chatKey: String
    let npub: String
    
    @State private var inputText: String = ""
    @FocusState private var isComposerFocused: Bool

    @Query private var messages: [Message]

    init(npub: String) {
        
        // Convert npub to a chatKey (hex)
        self.chatKey = try! PublicKey(npub: npub).hex
        
        // Use npub
        self.npub = npub
        
        _messages = Query(
            filter: #Predicate<Message> { message in
                message.chatKey == chatKey
            },
            sort: [SortDescriptor(\.createdAt, order: .forward)]
        )
    }

    private var recipient: String {
        self.npub
    }
    
    private var myPubKey: String? {
        datastore?.hex
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard let datastore else {
            print("[MessageView] No shared Datastore found in environment")
            return
        }

        do {
            try datastore.publishDirectMessage(to: recipient, plaintext: text)
            inputText = ""
        } catch {
            print("[MessageView] Error sending via datastore: \(error)")
        }
    }

    private func resetUnread() {
        let descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate { $0.npub == recipient }
        )

        if let contacts = try? modelContext.fetch(descriptor),
           let contact = contacts.first {
            contact.unreadCount = 0
            try? modelContext.save()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isMe: message.sender == myPubKey
                            )
                            .id(message.id)
                            .frame(minHeight: 20)
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .navigationTitle("\(npub.prefix(8))...")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            resetUnread()
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Message")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }

                    TextField("", text: $inputText, axis: .vertical)
                        .focused($isComposerFocused)
                        .lineLimit(1...6)
                        .onSubmit { sendMessage() }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                )

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(
                                canSend ? Color.blue : Color.gray.opacity(0.35)
                            )
                        )
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 40) }
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isMe ? Color.blue : Color(.secondarySystemBackground))
                .foregroundColor(isMe ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isMe { Spacer(minLength: 40) }
        }
        .padding(.vertical, 2)
    }
}
