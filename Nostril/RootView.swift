import SwiftUI

struct RootView: View {
    @AppStorage("myPubKey") private var myPubKey: String = ""

    var body: some View {
        if myPubKey.isEmpty {
            SignupView()
        } else {
            ContentView()
        }
    }
}

#Preview {
    RootView()
}
