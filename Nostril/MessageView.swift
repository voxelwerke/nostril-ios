import SwiftUI
import SwiftData

struct MessageView: View {
    @Environment(\.modelContext) private var modelContext

    let otherUserPubKey: String
    let myPubKey: String

    @State private var inputText: String = ""

    @Query(filter: #Predicate<Message> { _ in true }, sort: [
        SortDescriptor(\.createdAt, order: .forward)
    ]) private var messages: [Message]

    init(otherUserPubKey: String, myPubKey: String) {
        self.otherUserPubKey = otherUserPubKey
        self.myPubKey = myPubKey

        // Help the type-checker by capturing values and breaking the predicate into subexpressions
        let me = myPubKey
        let other = otherUserPubKey

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
                        }
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onAppear {
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("iMessage", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)

                Button(action: send) {
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

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let store = Datastore(modelContext: modelContext, myPubKey: myPubKey)
            _ = try store.postMessage(content: text, authorPubKey: myPubKey, otherPubKey: otherUserPubKey)
            inputText = ""
        } catch {
            // Handle error (log or show alert)
            print("Failed to send message: \(error)")
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
                .padding(10)
                .background(isMe ? Color.blue : Color(.secondarySystemBackground))
                .foregroundColor(isMe ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isMe { Spacer(minLength: 40) }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    do {
        let container = try Datastore.previewContainer()
        let context = ModelContext(container)
        // Seed preview data
        let me = "me"
        let other = "other"
        context.insert(Message(content: "Hey there", authorPubKey: me, otherPubKey: other))
        context.insert(Message(content: "Hi!", authorPubKey: other, otherPubKey: me))
        return NavigationStack { MessageView(otherUserPubKey: other, myPubKey: me) }
            .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}

