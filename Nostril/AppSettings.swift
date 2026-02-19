import SwiftUI

struct AppSettings {
    @AppStorage("displayName") var displayName: String = "Ben"
    @AppStorage("myPubKey") var myPubKey: String = ""
}
