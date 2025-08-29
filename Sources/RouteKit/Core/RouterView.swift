import SwiftUI

/// Main view that displays the current route
/// Equivalent to MaterialApp.router in Flutter's GoRouter
public struct RouterView: View {
    @ObservedObject private var router: RouteKit
    
    public init(router: RouteKit) {
        self.router = router
    }
    
    public var body: some View {
        Group {
            if let error = router.currentContext.error {
                // Show error view
                if let errorBuilder = router.errorBuilder {
                    errorBuilder(error)
                } else {
                    DefaultErrorView(error: error)
                }
            } else {
                // Show current route
                CurrentRouteView(router: router)
            }
        }
        .environmentObject(router)
        .environment(\.routeKit, router)
    }
}

/// View that renders the current route
private struct CurrentRouteView: View {
    @ObservedObject var router: RouteKit
    
    var body: some View {
        Group {
            if let matchingRoute = findMatchingRoute() {
                matchingRoute.builder(router.currentContext)
            } else {
                DefaultNotFoundView(path: router.currentPath)
            }
        }
    }
    
    private func findMatchingRoute() -> Route? {
        // Find the route that matches the current path
        for route in router.routes {
            if let _ = route.matches(path: router.currentPath) {
                return route
            }
            
            // Check child routes
            for childRoute in route.allRoutes {
                if let _ = childRoute.matches(path: router.currentPath) {
                    return childRoute
                }
            }
        }
        return nil
    }
}

/// Default error view when no custom error builder is provided
private struct DefaultErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Navigation Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Go Home") {
                if let router = RouteKitEnvironment.shared.current {
                    router.go("/")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// Default 404 not found view
private struct DefaultNotFoundView: View {
    let path: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Page Not Found")
                .font(.title)
                .fontWeight(.bold)
            
            Text("The page '\(path)' could not be found.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Go Home") {
                if let router = RouteKitEnvironment.shared.current {
                    router.go("/")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Environment Support

/// Environment key for RouteKit
private struct RouteKitEnvironmentKey: EnvironmentKey {
    static let defaultValue: RouteKit? = nil
}

extension EnvironmentValues {
    public var routeKit: RouteKit? {
        get { self[RouteKitEnvironmentKey.self] }
        set { self[RouteKitEnvironmentKey.self] = newValue }
    }
}

/// Global environment helper for accessing router
@MainActor
public class RouteKitEnvironment: ObservableObject {
    public static let shared = RouteKitEnvironment()
    public weak var current: RouteKit?
    
    private init() {}
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Navigate to a path using the environment router
    public func navigate(to path: String, extra: Any? = nil) {
        if let router = RouteKitEnvironment.shared.current {
            router.go(path, extra: extra)
        }
    }
    
    /// Push a path using the environment router
    public func pushRoute(_ path: String, extra: Any? = nil) {
        if let router = RouteKitEnvironment.shared.current {
            router.push(path, extra: extra)
        }
    }
    
    /// Pop the current route using the environment router
    public func popRoute() {
        if let router = RouteKitEnvironment.shared.current {
            router.pop()
        }
    }
}
