import SwiftUI
import RouteKit

// MARK: - Stateful Shell Route Example

struct StatefulShellExampleApp: App {
    @State private var router = createStatefulShellRouter()
    
    var body: some Scene {
        WindowGroup {
            RouterView(router: router)
                .onOpenURL { url in
                    router.handleDeepLink(url)
                }
        }
    }
}

// MARK: - Stateful Shell View

struct StatefulTabShellView: View {
    let context: RouteContext
    let navigationShell: StatefulNavigationShell
    
    var body: some View {
        TabView(selection: Binding(
            get: { navigationShell.currentIndex },
            set: { newIndex in navigationShell.goBranch(newIndex) }
        )) {
            // Each tab maintains its own navigation stack
            Group {
                // Home Tab (Branch 0)
                getCurrentView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .tag(0)
                
                // Search Tab (Branch 1)  
                getCurrentView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(1)
                
                // Favorites Tab (Branch 2)
                getCurrentView()
                    .tabItem {
                        Image(systemName: "heart")
                        Text("Favorites")
                    }
                    .tag(2)
                
                // Profile Tab (Branch 3)
                getCurrentView()
                    .tabItem {
                        Image(systemName: "person")
                        Text("Profile")
                    }
                    .tag(3)
            }
        }
    }
    
    @ViewBuilder
    private func getCurrentView() -> some View {
        if let router = navigationShell.router,
           let route = findCurrentRoute(for: router.currentPath) {
            route.builder(context)
        } else {
            Text("Route not found")
        }
    }
    
    private func findCurrentRoute(for path: String) -> Route? {
        // Find the route in the current branch
        guard let currentBranch = navigationShell.currentBranch else { return nil }
        
        for route in currentBranch.routes {
            if route.matches(path: path) != nil {
                return route
            }
            // Check nested routes
            for nestedRoute in route.allRoutes {
                if nestedRoute.matches(path: path) != nil {
                    return nestedRoute
                }
            }
        }
        return nil
    }
}

// MARK: - Branch Views

// Home Branch Views
struct StatefulHomeView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Home")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Stateful Navigation Example")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button("Go to Home Details") {
                        router?.push("/home/details/1")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Go to Home Settings") {
                        router?.push("/home/settings")
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Switch tabs and come back - your navigation state will be preserved!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

struct StatefulHomeDetailsView: View {
    let context: RouteContext
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Home Details")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let detailId = context.pathParameter("detailId") {
                Text("Detail ID: \(detailId)")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button("Go Deeper") {
                router?.push("/home/details/1/deep")
            }
            .buttonStyle(.borderedProminent)
            
            Button("Back") {
                router?.pop()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Details")
    }
}

struct StatefulHomeDeepView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Deep View")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This is 3 levels deep in the Home tab!")
                .multilineTextAlignment(.center)
            
            Text("Switch to another tab and back - this state is preserved.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Back") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Deep")
    }
}

// Search Branch Views
struct StatefulSearchView: View {
    @State private var searchText = ""
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Enter search term...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button("Search") {
                    if !searchText.isEmpty {
                        router?.push("/search/results?q=\(searchText)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
                
                Text("Each tab maintains its own navigation stack independently!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("Search")
        }
    }
}

// Favorites Branch Views  
struct StatefulFavoritesView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Favorites")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                List {
                    ForEach(1...10, id: \.self) { index in
                        Button("Favorite Item \(index)") {
                            router?.push("/favorites/item/\(index)")
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
        }
    }
}

struct StatefulFavoriteItemView: View {
    let context: RouteContext
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Favorite Item")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let itemId = context.pathParameter("itemId") {
                Text("Item #\(itemId)")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            Button("Back to Favorites") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Item")
    }
}

// Profile Branch Views
struct StatefulProfileView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button("Account Settings") {
                    router?.push("/profile/settings")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Privacy Settings") {
                    router?.push("/profile/privacy")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Router Configuration

@MainActor
func createStatefulShellRouter() -> RouteKit {
    let homeBranch = StatefulShellBranch(
        id: "home",
        routes: [
            Route(path: "/home", name: "statefulHome") { _ in
                StatefulHomeView()
            },
            Route(path: "/home/details/:detailId", name: "statefulHomeDetails") { context in
                StatefulHomeDetailsView(context: context)
            },
            Route(path: "/home/details/:detailId/deep", name: "statefulHomeDeep") { _ in
                StatefulHomeDeepView()
            },
            Route(path: "/home/settings", name: "statefulHomeSettings") { _ in
                StatefulHomeSettingsView()
            }
        ],
        initialLocation: "/home"
    )
    
    let searchBranch = StatefulShellBranch(
        id: "search",
        routes: [
            Route(path: "/search", name: "statefulSearch") { _ in
                StatefulSearchView()
            },
            Route(path: "/search/results", name: "statefulSearchResults") { context in
                StatefulSearchResultsView(context: context)
            }
        ],
        initialLocation: "/search"
    )
    
    let favoritesBranch = StatefulShellBranch(
        id: "favorites",
        routes: [
            Route(path: "/favorites", name: "statefulFavorites") { _ in
                StatefulFavoritesView()
            },
            Route(path: "/favorites/item/:itemId", name: "statefulFavoriteItem") { context in
                StatefulFavoriteItemView(context: context)
            }
        ],
        initialLocation: "/favorites"
    )
    
    let profileBranch = StatefulShellBranch(
        id: "profile",
        routes: [
            Route(path: "/profile", name: "statefulProfile") { _ in
                StatefulProfileView()
            },
            Route(path: "/profile/settings", name: "statefulProfileSettings") { _ in
                StatefulProfileSettingsView()
            },
            Route(path: "/profile/privacy", name: "statefulProfilePrivacy") { _ in
                StatefulProfilePrivacyView()
            }
        ],
        initialLocation: "/profile"
    )
    
    let router = RouteKit(
        statefulShellRoutes: [
            StatefulShellRoute.indexedStack(
                branches: [homeBranch, searchBranch, favoritesBranch, profileBranch]
            ) { context, navigationShell in
                StatefulTabShellView(context: context, navigationShell: navigationShell)
            }
        ],
        initialRoute: "/home",
        debugLogDiagnostics: true
    )
    
    return router
}

// MARK: - Additional Views (Placeholders)

struct StatefulHomeSettingsView: View {
    var body: some View {
        Text("Home Settings")
            .navigationTitle("Settings")
    }
}

struct StatefulSearchResultsView: View {
    let context: RouteContext
    
    var body: some View {
        VStack {
            if let query = context.queryParameter("q") {
                Text("Results for: \(query)")
            }
        }
        .navigationTitle("Results")
    }
}

struct StatefulProfileSettingsView: View {
    var body: some View {
        Text("Profile Settings")
            .navigationTitle("Settings")
    }
}

struct StatefulProfilePrivacyView: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

// MARK: - Preview

#Preview("Stateful Shell Example") {
    let router = createStatefulShellRouter()
    return RouterView(router: router)
}
