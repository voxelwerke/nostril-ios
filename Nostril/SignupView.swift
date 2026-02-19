import SwiftUI

struct SignupView: View {
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("myPubKey") private var myPubKey: String = ""

    @State private var tempDisplayName: String = ""
    @State private var generatedPubKey: String = ""
    @State private var isImportingPrivateKey: Bool = false
    @State private var importedPrivateKey: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome to Nost")
                    .font(.largeTitle).bold()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Username:")
                        .font(.headline)
                    TextField("Enter a username", text: $tempDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                if isImportingPrivateKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("your private key:")
                            .font(.headline)
                        TextField("Paste your private key", text: $importedPrivateKey, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your new public key:")
                            .font(.headline)
                        Text(generatedPubKey.isEmpty ? "Will be generated" : generatedPubKey)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                Text("Your private key will be stored in your keychain. ")
                
                Text("Import key").underline().foregroundStyle(.blue).onTapGesture {
                    withAnimation { isImportingPrivateKey.toggle() }
                }

                Spacer()

                Button(action: beginTapped) {
                    Text("Begin")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canBegin ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!canBegin)
            }
            .padding()
            .onAppear(perform: prepareKeys)
        }
    }

    private var canBegin: Bool {
        if isImportingPrivateKey {
            return !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !importedPrivateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func prepareKeys() {
        // Generate a placeholder public key for demo purposes
        if generatedPubKey.isEmpty {
            generatedPubKey = "npub1-" + String(Int.random(in: 100000...999999))
        }
    }

    private func beginTapped() {
        // Persist display name
        displayName = tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isImportingPrivateKey {
            // Store the private key in keychain (stubbed here). Derive public key from the private key.
            storePrivateKeyInKeychain(importedPrivateKey)
            // For demo, derive a fake public key from private key length
            myPubKey = "npub1-" + String(importedPrivateKey.hashValue & 0xFFFF)
        } else {
            // Store the generated public key
            myPubKey = generatedPubKey
            // Also create and store a private key in keychain (stubbed)
            let newPrivateKey = "nsec1-" + String(Int.random(in: 100000...999999))
            storePrivateKeyInKeychain(newPrivateKey)
        }
    }

    private func storePrivateKeyInKeychain(_ key: String) {
        // TODO: Replace with real Keychain storage.
        print("[Signup] Stored private key in keychain: \(key.prefix(8))…")
    }
}

#Preview {
    SignupView()
}
