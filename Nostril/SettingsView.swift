import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("displayName") private var displayName: String = "Ben"
    @AppStorage("myPubKey") private var myPubKey: String = ""

    @State private var showingLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tukutuku()
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header Block
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.largeTitle.weight(.bold))
                        
                        Text("Manage your profile and preferences")
                            .font(.subheadline)
                            .opacity(0.7)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(30)
                    
                    // Profile Form Block
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.headline)
                            
                            TextField("Display Name", text: $displayName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 28, weight: .bold))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                            
                            Divider()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Public Key")
                                    .font(.headline)
                                
                                Spacer()
                                
                                // Share Button
                                if !myPubKey.isEmpty {
                                    ShareLink(item: myPubKey) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .buttonStyle(CircleButtonStyle())
                                }
                            }
                            
                            Text(truncatedPubKey)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(30)
                    
                    // Log Out Button
                    Button(role: .destructive) {
                        showingLogoutConfirm = true
                    } label: {
                        Text("Log Out")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                            )
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                    
                    Spacer(minLength: 100)
                }
                .padding(48)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
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
    
    private var truncatedPubKey: String {
        if myPubKey.isEmpty {
            return "Not set"
        }
        guard myPubKey.count > 20 else {
            return myPubKey
        }
        return "\(myPubKey.prefix(10))...\(myPubKey.suffix(8))"
    }
}

#Preview {
    SettingsView()
}
