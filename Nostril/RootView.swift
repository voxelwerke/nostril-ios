import SwiftUI

struct RootView: View {
    @AppStorage("myPubKey") private var myPubKey: String = ""

    var body: some View {
        // Setup is complete only when we have BOTH:
        // - a public key persisted in AppStorage
        // - a private key persisted in Keychain
        let hasPrivateKey = (KeychainStore.loadNsec() != nil)

        if myPubKey.isEmpty || !hasPrivateKey {
            SignupView()
        } else {
            ContentView()
        }
    }
}

#Preview {
    RootView()
}
