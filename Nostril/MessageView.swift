import SwiftUI
import SwiftData

struct MessageView: View {
    // MARK: - Logging
    private func log(_ message: String) {
        print("[MessageView] \(message)")
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore

    let otherUserPubKey: String
    let myPubKey: String

    @State private var inputText: String = ""

    @Query(filter: #Predicate<Message> { _ in true }, sort: [
        SortDescriptor(\.createdAt, order: .forward)
    ]) private var messages: [Message]

    init(otherUserPubKey: String, myPubKey: String) {
        self.otherUserPubKey = otherUserPubKey
        self.myPubKey = myPubKey

        log("Init with myPubKey=\(myPubKey), otherUserPubKey=\(otherUserPubKey)")

        // Help the type-checker by capturing values and breaking the predicate into subexpressions
        let me = myPubKey
        let other = otherUserPubKey

        log("Configuring messages Query predicate for conversation between me=\(me) and other=\(other)")

        _messages = Query(
            filter: #Predicate<Message> { message in
                ((message.authorPubKey == me) && (message.otherPubKey == other)) ||
                ((message.authorPubKey == other) && (message.otherPubKey == me))
            },
            sort: [
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, isMe: message.authorPubKey == myPubKey)
                                .id(message.id)
                                .padding(.horizontal, 12)
                                .onAppear {
                                    log("Rendering bubble for message id=\(String(describing: message.id)), author=\(message.authorPubKey), other=\(message.otherPubKey), createdAt=\(message.createdAt)")
                                }
                        }
                    }
                }
                .onAppear {
                    log("ScrollView appeared. Current messages count=\(messages.count)")
                }
                .onChange(of: messages.count) { old, new in
                    log("messages.count changed from \(old) to \(new)")
                    if let last = messages.last {
                        log("Auto-scrolling to last message id=\(String(describing: last.id)) at appear/change")
                        proxy.scrollTo(last.id, anchor: .bottom)
                    } else {
                        log("No messages to scroll to")
                    }
                }
                .onAppear {
                    log("MessageView appeared. messages.count=\(messages.count)")
                    if let last = messages.last {
                        log("Scrolling to last message id=\(String(describing: last.id)) on appear")
                        proxy.scrollTo(last.id, anchor: .bottom)
                    } else {
                        log("No messages to scroll to on appear")
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("iMessage", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)

                Button(action: {
                    let text = inputText
                    print("Sending message")
                    
                    do {
                        guard let datastore else {
                            print("[MessageView] No shared Datastore found in environment")
                            return
                        }
                        _ = try datastore.publishDirectMessage(to: otherUserPubKey, plaintext: text)
                        inputText = ""
                    } catch {
                        print("[MessageView] Error sending via datastore: \(error)")
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.palette)
                        .background(
                            Circle().fill(.blue).frame(width: 32, height: 32)
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.all, 12)
            .background(.thinMaterial)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 40) }
            Text(message.content)
                .padding(10)
                .background(isMe ? Color.blue : Color(.secondarySystemBackground))
                .foregroundColor(isMe ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isMe { Spacer(minLength: 40) }
        }
        .padding(.vertical, 2)
    }
}

