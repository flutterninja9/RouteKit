import SwiftUI
import RouteKit

// MARK: - Sample Views

struct HomeView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("RouteKit Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Welcome to the Home Page")
                .font(.title2)
            
            VStack(spacing: 12) {
                Button("Go to About") {
                    router?.go("/about")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Go to User Profile") {
                    router?.go("/users/123")
                }
                .buttonStyle(.bordered)
                
                Button("Navigate with Named Route") {
                    router?.goNamed("userProfile", pathParameters: ["userId": "456"])
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("Home")
    }
}

struct AboutView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("About RouteKit")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("RouteKit is a SwiftUI port of Flutter's GoRouter, providing declarative, URL-based navigation.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Go Back Home") {
                router?.go("/")
            }
            .buttonStyle(.borderedProminent)
            
            Button("Push Settings") {
                router?.push("/settings")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("About")
    }
}

struct UserProfileView: View {
    @Environment(\.routeKit) var router
    let context: RouteContext
    
    init(context: RouteContext) {
        self.context = context
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("User Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let userId = context.pathParameter("userId") {
                Text("User ID: \(userId)")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            if let filter = context.queryParameter("filter") {
                Text("Filter: \(filter)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Button("Go Home") {
                router?.go("/")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Profile")
    }
}

struct SettingsView: View {
    @Environment(\.routeKit) var router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("App Settings")
                .font(.title2)
            
            Button("Pop Back") {
                router?.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Settings")
    }
}

// MARK: - Router Configuration

@MainActor
func createSampleRouter() -> RouteKit {
    let routes = [
        Route(path: "/", name: "home") { _ in
            HomeView()
        },
        
        Route(path: "/about", name: "about") { _ in
            AboutView()
        },
        
        Route(path: "/users/:userId", name: "userProfile") { context in
            UserProfileView(context: context)
        },
        
        Route(path: "/settings") { _ in
            SettingsView()
        }
    ]
    
    return RouteKit(
        routes: routes,
        initialRoute: "/",
        debugLogDiagnostics: true
    )
}

// MARK: - Sample App

@main
struct RouteKitExampleApp: App {
    @State private var router = createSampleRouter()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                RouterView(router: router)
            }
            .onOpenURL { url in
                router.handleDeepLink(url)
            }
        }
    }
}

#Preview {
    let router = createSampleRouter()
    return NavigationView {
        RouterView(router: router)
    }
}
