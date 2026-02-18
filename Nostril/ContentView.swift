//
//  ContentView.swift
//  Nostril
//
//  Created by Ben Nolan on 19/02/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // In a real app, provide the signed-in user's pubkey via environment or auth
    @State private var myPubKey: String = "my-pubkey-placeholder"

    // Temporary hardcoded contacts for demo
    @State private var contacts: [String] = [
        "npub1-alice",
        "npub1-bob",
        "npub1-carol"
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(contacts, id: \.self) { pub in
                    NavigationLink(destination: MessageView(otherUserPubKey: pub, myPubKey: myPubKey)) {
                        HStack {
                            Circle().fill(.blue).frame(width: 36, height: 36)
                            Text(pub)
                        }
                    }
                }
            }
            .navigationTitle("Nostril")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Placeholder: add a new contact
                        contacts.append("npub1-\(Int.random(in: 1000...9999))")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

/*
 Original code for reference:

 struct ContentView: View {
     @Environment(\.modelContext) private var modelContext
     @Query private var items: [Item]

     var body: some View {
         NavigationSplitView {
             List {
                 ForEach(items) { item in
                     NavigationLink {
                         Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                     } label: {
                         Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                     }
                 }
                 .onDelete(perform: deleteItems)
             }
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     EditButton()
                 }
                 ToolbarItem {
                     Button(action: addItem) {
                         Label("Add Item", systemImage: "plus")
                     }
                 }
             }
         } detail: {
             Text("Select an item")
         }
     }

     private func addItem() {
         withAnimation {
             let newItem = Item(timestamp: Date())
             modelContext.insert(newItem)
         }
     }

     private func deleteItems(offsets: IndexSet) {
         withAnimation {
             for index in offsets {
                 modelContext.delete(items[index])
             }
         }
     }
 }
*/

#Preview {
    ContentView()
}
