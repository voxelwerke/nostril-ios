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
    @State private var selectedMessageID: String?

    @Query private var messages: [Message]
    @Query private var reactions: [Reaction]   // ✅ no filter

    init(npub: String) {
        self.chatKey = try! PublicKey(npub: npub).hex
        self.npub = npub
        
        _messages = Query(
            filter: #Predicate<Message> { message in
                message.chatKey == chatKey
            },
            sort: [SortDescriptor(\.createdAt, order: .forward)]
        )
    }

    private var recipient: String { npub }
    private var myPubKey: String? { datastore?.hex }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Reaction Helpers

    private func reactions(for message: Message) -> [Reaction] {
        reactions.filter { $0.targetMessageId == message.id }
    }

    private func groupedReactions(for message: Message)
    -> [(emoji: String, count: Int, isMine: Bool)] {

        let grouped = Dictionary(grouping: reactions(for: message), by: \.emoji)

        return grouped.map { emoji, reactions in
            (
                emoji: emoji,
                count: reactions.count,
                isMine: reactions.contains { $0.sender == myPubKey }
            )
        }
        .sorted { $0.emoji < $1.emoji }
    }

    private func sendReaction(_ emoji: String, for message: Message) {
        guard let datastore else { return }

        datastore.sendReaction(
            emoji: emoji,
            to: message.sender == myPubKey
                ? message.recipient
                : message.sender,
            reactingTo: message.id
        )
    }

    // MARK: - Messaging

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let datastore else { return }

        datastore.publishDirectMessage(to: recipient, plaintext: text)
        inputText = ""
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
    
    // MARK: - UI

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                VStack(
                                    alignment: message.sender == myPubKey ? .trailing : .leading,
                                    spacing: 4
                                ) {
                                    
                                    MessageBubble(
                                        message: message,
                                        isMe: message.sender == myPubKey
                                    )
                                    .overlay(alignment: .top) {
                                        if selectedMessageID == message.id {
                                            ReactionPicker { emoji in
                                                sendReaction(emoji, for: message)
                                                withAnimation {
                                                    selectedMessageID = nil
                                                }
                                            }
                                            .offset(y: -55)
                                            .transition(.scale.combined(with: .opacity))
                                            .zIndex(1)
                                        }
                                    }
                                    .onLongPressGesture {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedMessageID = message.id
                                        }
                                    }

                                    let grouped = groupedReactions(for: message)
                                    if !grouped.isEmpty {
                                        ReactionBar(reactions: grouped)
                                    }
                                }
                                .id(message.id)
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
            .onAppear { resetUnread() }

            if selectedMessageID != nil {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            selectedMessageID = nil
                        }
                    }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message", text: $inputText, axis: .vertical)
                    .focused($isComposerFocused)
                    .lineLimit(1...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.secondarySystemBackground))
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
            }
            .padding()
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
    }
}

private struct ReactionPicker: View {
    let emojis = ["❤️","👍","👎","😂","😮","😢"]
    let onSelect: (String) -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ForEach(emojis, id: \.self) { emoji in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .padding(6)
                        .background(
                            Circle().fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .shadow(radius: 10)
    }
}

private struct ReactionBar: View {
    let reactions: [(emoji: String, count: Int, isMine: Bool)]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(reactions, id: \.emoji) { reaction in
                HStack(spacing: 4) {
                    Text(reaction.emoji)
                    if reaction.count > 1 {
                        Text("\(reaction.count)")
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        reaction.isMine
                        ? Color.blue.opacity(0.15)
                        : Color(.secondarySystemBackground)
                    )
                )
            }
        }
    }
}

