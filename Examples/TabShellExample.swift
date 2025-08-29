import SwiftUI
import RouteKit

// MARK: - Shell Route Example with Tab Navigation

struct TabShellExampleApp: App {
    @State private var router = createTabRouter()
    
    var body: some Scene {
        WindowGroup {
            RouterView(router: router)
                .onOpenURL { url in
                    router.handleDeepLink(url)
                }
        }
    }
}

// MARK: - Tab Views

struct TabShellView: View {
    let context: RouteContext
    let child: AnyView
    @Environment(\.routeKit) var router
    
    var body: some View {
        TabView(selection: Binding(
            get: { currentTabFromPath() },
            set: { newTab in navigateToTab(newTab) }
        )) {
            child
                .tabItem {
                    Image(systemName: tabIcon(for: currentTabFromPath()))
                    Text(tabTitle(for: currentTabFromPath()))
                }
                .tag(currentTabFromPath())
        }
    }
    
    private func currentTabFromPath() -> Int {
        if context.fullPath.hasPrefix("/home") { return 0 }
        if context.fullPath.hasPrefix("/search") { return 1 }
        if context.fullPath.hasPrefix("/profile") { return 2 }
        return 0
    }
    
    private func navigateToTab(_ tab: Int) {
        switch tab {
        case 0: router?.go("/home")
        case 1: router?.go("/search")
        case 2: router?.go("/profile")
        default: break
        }
    }
    
    private func tabIcon(for tab: Int) -> String {
        switch tab {
        case 0: return "house"
        case 1: return "magnifyingglass"
        case 2: return "person"
        default: return "circle"
        }
    }
    
    private func tabTitle(for tab: Int) -> String {
        switch tab {
        case 0: return "Home"
        case 1: return "Search"
        case 2: return "Profile"
        default: return "Tab"
        }
    }
}

// MARK: - Tab Content Views

struct HomeTabView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Home Tab")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Welcome to RouteKit Shell Routes!")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button("Go to Details") {
                        router?.push("/home/details")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Go to Settings") {
                        router?.push("/home/settings")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

struct HomeDetailsView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Home Details")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This is a detail view within the Home tab.")
                .multilineTextAlignment(.center)
            
            Button("Go Back") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Go to Profile Tab") {
                router?.go("/profile")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Details")
    }
}

struct HomeSettingsView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Home Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Settings for the Home tab.")
                .multilineTextAlignment(.center)
            
            Button("Go Back") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Settings")
    }
}

struct SearchTabView: View {
    @State private var searchText = ""
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Search Tab")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button("Perform Search") {
                    router?.push("/search/results?q=\(searchText)")
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
            }
            .padding()
            .navigationTitle("Search")
        }
    }
}

struct SearchResultsView: View {
    let context: RouteContext
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Search Results")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let query = context.queryParameter("q") {
                Text("Results for: \"\(query)\"")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Mock search results
            List {
                ForEach(1...5, id: \.self) { index in
                    Button("Result \(index)") {
                        router?.push("/search/detail/\(index)")
                    }
                }
            }
            
            Button("Back to Search") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Results")
    }
}

struct ProfileTabView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                Text("Profile Tab")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("User Profile Information")
                    .font(.title2)
                
                VStack(spacing: 12) {
                    Button("Edit Profile") {
                        router?.push("/profile/edit")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Account Settings") {
                        router?.push("/profile/settings")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

struct ProfileEditView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Profile editing interface would go here.")
                .multilineTextAlignment(.center)
            
            Button("Save Changes") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Edit")
    }
}

// MARK: - Router Configuration

@MainActor
func createTabRouter() -> RouteKit {
    let router = RouteKit(
        shellRoutes: [
            ShellRoute(routes: [
                // Home tab routes
                Route(path: "/home", name: "home") { _ in
                    HomeTabView()
                },
                Route(path: "/home/details", name: "homeDetails") { _ in
                    HomeDetailsView()
                },
                Route(path: "/home/settings", name: "homeSettings") { _ in
                    HomeSettingsView()
                },
                
                // Search tab routes
                Route(path: "/search", name: "search") { _ in
                    SearchTabView()
                },
                Route(path: "/search/results", name: "searchResults") { context in
                    SearchResultsView(context: context)
                },
                
                // Profile tab routes
                Route(path: "/profile", name: "profile") { _ in
                    ProfileTabView()
                },
                Route(path: "/profile/edit", name: "profileEdit") { _ in
                    ProfileEditView()
                }
            ]) { context, child in
                TabShellView(context: context, child: child)
            }
        ],
        initialRoute: "/home",
        debugLogDiagnostics: true
    )
    
    return router
}

// MARK: - Preview

#Preview("Tab Shell Example") {
    let router = createTabRouter()
    return RouterView(router: router)
}
