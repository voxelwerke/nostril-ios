//
//  NostrilApp.swift
//  Nostril
//
//  Created by Ben Nolan on 19/02/2026.
//

import SwiftUI
import SwiftData

@main
struct NostrilApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    private let sharedDatastore: Datastore

    init() {
        // Initialize a shared Datastore for the app session
        let context = ModelContext(sharedModelContainer)
        // In a real app, obtain myPubKey from authentication/session
        let myPubKey = "my-pubkey-placeholder"
        self.sharedDatastore = Datastore(modelContext: context, myPubKey: myPubKey)
        print("[App] Shared Datastore initialized with myPubKey=\(myPubKey)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.datastore, sharedDatastore)
        }
        .modelContainer(sharedModelContainer)
    }
}
