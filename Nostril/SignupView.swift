import SwiftUI
import NostrClient
import Security


struct SignupView: View {
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("myPubKey") private var myPubKey: String = ""

    @State private var tempDisplayName: String = ""
    @State private var generatedPubKey: String = ""
    @State private var generatedPrivateKey: String = ""
    @State private var isImportingPrivateKey: Bool = false
    @State private var importedPrivateKey: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome to Nostril")
                    .font(.largeTitle.weight(.semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Username")
                        .font(.headline)
                    TextField("Enter a username", text: $tempDisplayName)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    Divider()
                }

                if isImportingPrivateKey {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Private key")
                            .font(.headline)
                        TextField("Paste your private key", text: $importedPrivateKey, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3, reservesSpace: true)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Divider()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your nostr identity (npub)")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(displayedNpub)
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Divider()
                            }

                            Button {
                                regenerateKeys()
                            } label: {
                                Image(systemName: "dice")
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Regenerate key")
                        }
                    }
                }

                Text("Your private key will be stored in your keychain. ")
                
                Button {
                    withAnimation { isImportingPrivateKey.toggle() }
                } label: {
                    Text(isImportingPrivateKey ? "Generate new key" : "Import key")
                        .underline()
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Begin", action: beginTapped)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canBegin)
            }
            .padding()
            .onAppear(perform: prepareKeys)
        }
    }

    private var displayedNpub: String {
        let raw = generatedPubKey.isEmpty ? "Will be generated" : generatedPubKey
        // Common UI convention: show a short prefix and suffix with an ellipsis in the middle.
        // Example: npub1abcd…wxyz
        return truncateMiddle(raw, prefix: 10, suffix: 8)
    }

    private var canBegin: Bool {
        if isImportingPrivateKey {
            return !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !importedPrivateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func prepareKeys() {
        if generatedPubKey.isEmpty {
            regenerateKeys()
        }
    }

    private func regenerateKeys() {
        do {
            // Generate a real nostr keypair via NostrClient
            let kp = try KeyPair()
            // Display npub in the UI
            generatedPubKey = kp.npub
            // Store nsec for persistence on Begin
            generatedPrivateKey = kp.nsec
        } catch {
            generatedPubKey = ""
            generatedPrivateKey = ""
            print("❌ [Signup] Failed to generate keys: \(error)")
        }
    }

    private func beginTapped() {
        // Persist display name
        displayName = tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isImportingPrivateKey {
            // Store the private key in keychain (stubbed here). Derive public key from the private key.
            storePrivateKeyInKeychain(importedPrivateKey)
            do {
                let kp = try KeyPair(nsec: importedPrivateKey)
                myPubKey = kp.npub
            } catch {
                print("❌ [Signup] Invalid imported private key: \(error)")
                myPubKey = ""
            }
        } else {
            // Store the generated public key (npub)
            myPubKey = generatedPubKey
            // Store the generated private key (nsec) in keychain
            storePrivateKeyInKeychain(generatedPrivateKey)
        }
    }

    private func truncateMiddle(_ s: String, prefix: Int, suffix: Int) -> String {
        guard s.count > prefix + suffix + 1 else { return s }
        let start = s.prefix(prefix)
        let end = s.suffix(suffix)
        return "\(start)…\(end)"
    }

    private func storePrivateKeyInKeychain(_ key: String) {
        KeychainStore.saveNsec(key)
    }
}

#Preview {
    SignupView()
}
