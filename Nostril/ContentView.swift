import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore
    
    @State private var showSettings = false
    @State private var selectedTab: String = "Chat"
    
    // ✅ Navigation state (Messages-style)
    @State private var path = NavigationPath()
    
    @Query(sort: \Contact.lastMessageDate, order: .reverse) private var contacts: [Contact]
    
    private var myPubKey: String? {
        datastore?.npub
    }
    
    // ✅ Hide when pushed
    private var isTabBarHidden: Bool {
        !path.isEmpty
    }
        
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // ✅ NavigationStack owned here
            NavigationStack(path: $path) {
                ChatView(path: $path)
            }
            
            // Floating Tab Bar
            HStack(spacing: 15) {
                HStack(spacing: 0) {
                    TabButton(title: "Chat", selection: $selectedTab)
                    TabButton(title: "Space", selection: $selectedTab)
                    TabButton(title: "Explore", selection: $selectedTab)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            }
            .padding(.bottom, 20)
            .offset(y: isTabBarHidden ? 140 : 0)     // ✅ slide down
            .opacity(isTabBarHidden ? 0 : 1)
            .animation(.easeInOut(duration: 0.25), value: isTabBarHidden)
        }
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Button(action: { selection = title }) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    selection == title
                    ? AnyView(Capsule().fill(.white.opacity(0.2)))
                    : AnyView(EmptyView())
                )
                .foregroundColor(.primary)
        }
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

