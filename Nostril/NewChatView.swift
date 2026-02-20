//
//  NewChatView.swift
//  Nostril
//
//  Created by Ben Nolan on 20/02/2026.
//


import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var npub: String = ""
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                TextField("Enter npub", text: $npub)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onSubmit {
                        openChat()
                    }
                
                Spacer()
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { npub in
                MessageView(npub: npub)
            }
        }
    }
    
    private func openChat() {
        let trimmed = npub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        path.append(trimmed)
    }
}
