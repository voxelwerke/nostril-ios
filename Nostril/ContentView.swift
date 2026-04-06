import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.datastore) private var datastore
    
    @State private var selectedTab: String = "Chat"
    @State private var isTabBarHidden: Bool = false
    
    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case "Chat":
                    ChatView(isTabBarHidden: $isTabBarHidden)
                case "Space":
                    Text("Space")
                case "News":
                    NewsView()
                default:
                    ChatView(isTabBarHidden: $isTabBarHidden)
                }
            }
            .safeAreaInset(edge: .bottom) {
                tabBar
                    .offset(y: isTabBarHidden ? 120 : 0)
                    .opacity(isTabBarHidden ? 0 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isTabBarHidden)
            }
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 15) {
            
            // Share Button
            ShareLink(item: datastore?.npub ?? "something") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(CircleButtonStyle())
            
            HStack(spacing: 0) {
                TabButton(title: "Chat", selection: $selectedTab)
//                TabButton(title: "Space", selection: $selectedTab)
                TabButton(title: "News", selection: $selectedTab)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .padding(.horizontal)
            .padding(.top, 8)

            // ✅ New message button now navigates
            NavigationLink {
                NewChatView()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(CircleButtonStyle())
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

// MARK: - News View

struct NewsView: View {
    @State private var refreshTrigger = false
    
    var body: some View {
        WebView(url: URL(string: "https://www.bennolan.com")!, refreshTrigger: $refreshTrigger)
            .ignoresSafeArea()
    }
}

// MARK: - WebView Wrapper

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var refreshTrigger: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // Add pull-to-refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
        webView.scrollView.bounces = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    class Coordinator: NSObject {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
            if let webView = refreshControl.superview?.superview as? WKWebView {
                webView.reload()
                
                // End refreshing after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    refreshControl.endRefreshing()
                }
            }
        }
    }
}


