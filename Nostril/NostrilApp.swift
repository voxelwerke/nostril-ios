import SwiftUI
import SwiftData
import Combine

@main
struct NostrilApp: App {

    var sharedModelContainer: ModelContainer
    @StateObject private var datastoreHolder: DatastoreHolder

    init() {
        let container = Self.createContainer()
        self.sharedModelContainer = container

        _datastoreHolder = StateObject(
            wrappedValue: DatastoreHolder(context: container.mainContext)
        )
    }

    static func createContainer() -> ModelContainer {
        let schema = Schema([Contact.self, Message.self, Item.self])
        return try! ModelContainer(for: schema)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.datastore, datastoreHolder.datastore)
                .environmentObject(datastoreHolder)
        }
        .modelContainer(sharedModelContainer)
    }
}

final class DatastoreHolder: ObservableObject {

    private let context: ModelContext

    @Published private(set) var datastore: Datastore?

    init(context: ModelContext) {
        self.context = context

        // Initialize if key already exists
        if KeychainStore.loadNsec() != nil {
            self.datastore = Datastore(modelContext: context)
        }
    }

    /// Call this after signup stores an nsec
    func rebuildIfNeeded() {
        guard KeychainStore.loadNsec() != nil else { return }

        datastore = Datastore(modelContext: context)
    }
}

