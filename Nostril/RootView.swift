import SwiftUI

struct RootView: View {
    var body: some View {
        // Setup is complete only when we have:
        // - a private key persisted in Keychain
        let hasPrivateKey = false // (KeychainStore.loadNsec() != nil)

        if !hasPrivateKey {
            SignupView()
        } else {
            ContentView()
        }
    }
}

#Preview {
    RootView()
}
