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
        let context = ModelContext(sharedModelContainer)
        _datastoreHolder = StateObject(wrappedValue: DatastoreHolder(context: context))
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

