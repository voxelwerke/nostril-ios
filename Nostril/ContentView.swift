import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore
    
    @State private var selectedTab: String = "Chat"
    
    var body: some View {
        Group {
            switch selectedTab {
            case "Chat":
                ChatView()
            case "Space":
                Text("Space")
            case "Explore":
                Text("Explore")
            default:
                ChatView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            tabBar
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "Chat", selection: $selectedTab)
            TabButton(title: "Space", selection: $selectedTab)
            TabButton(title: "Explore", selection: $selectedTab)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal)
        .padding(.top, 8)
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
                    ? Capsule().fill(.white.opacity(0.2))
                    : nil
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

