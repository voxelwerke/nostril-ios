import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("displayName") private var displayName: String = "Ben"
    @AppStorage("myPubKey") private var myPubKey: String = ""

    @State private var showingLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Display Name", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Keys")) {
                    HStack {
                        Text("Public Key")
                        Spacer()
                        Text(myPubKey.isEmpty ? "Not set" : myPubKey)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirm = true
                    } label: {
                        Text("Log Out")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Log Out?", isPresented: $showingLogoutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("Your private key will be backed up to this device before logging out.")
            }
        }
    }

    private func performLogout() {
        // Backup current private key into backups list
        KeychainStore.logout()

        // Clear public key (this forces RootView back to SignupView)
        myPubKey = ""

        dismiss()
    }
}

#Preview {
    SettingsView()
}
