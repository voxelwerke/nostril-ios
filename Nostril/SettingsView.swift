import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private var settings = AppSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Display Name", text: settings.$displayName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Keys")) {
                    HStack {
                        Text("Public Key")
                        Spacer()
                        Text(settings.myPubKey.isEmpty ? "Not set" : settings.myPubKey)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
