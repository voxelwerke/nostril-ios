import Foundation
import SwiftData

final class Datastore {
    private let modelContext: ModelContext
    private let myPubKey: String

    init(modelContext: ModelContext, myPubKey: String) {
        self.modelContext = modelContext
        self.myPubKey = myPubKey
    }

    // Returns a descriptor to be used with @Query in views
    func messagesFetchDescriptor(for otherPubKey: String) -> FetchDescriptor<Message> {
        return FetchDescriptor<Message>(
            predicate: #Predicate { message in
                message.authorPubKey == myPubKey || message.authorPubKey == otherPubKey
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
    }

    @discardableResult
    func postMessage(content: String, authorPubKey: String, otherPubKey: String) throws -> Message {
        let message = Message(content: content, authorPubKey: authorPubKey, otherPubKey: otherPubKey)
        modelContext.insert(message)
        try modelContext.save()
        return message
    }

    func deleteMessage(_ message: Message) throws {
        modelContext.delete(message)
        try modelContext.save()
    }

    func updateMessage(_ message: Message, newContent: String) throws {
        message.content = newContent
        try modelContext.save()
    }

    // Helper for previews/tests
    static func previewContainer(inMemory: Bool = true) throws -> ModelContainer {
        let schema = Schema([Message.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

