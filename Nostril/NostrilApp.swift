//
//  NostrilApp.swift
//  Nostril
//
//  Created by Ben Nolan on 19/02/2026.
//

import SwiftUI
import SwiftData
import Combine

@main
struct NostrilApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Contact.self,
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @StateObject private var datastoreHolder: DatastoreHolder

    init() {
        // This ensures the Datastore and the UI share the same memory space
        let container = Self.createContainer()
        self.sharedModelContainer = container
        
        _datastoreHolder = StateObject(wrappedValue: DatastoreHolder(context: container.mainContext))
    }

// Helper to ensure init and property use same container
    static func createContainer() -> ModelContainer {
        let schema = Schema([Contact.self, Message.self, Item.self])
        return try! ModelContainer(for: schema)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.datastore, datastoreHolder.datastore)
        }
        .modelContainer(sharedModelContainer)
    }

}


final class DatastoreHolder: ObservableObject {
    let datastore: Datastore

    init(context: ModelContext) {
        datastore = Datastore(modelContext: context)
    }
}

