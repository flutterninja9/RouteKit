import Foundation
import SwiftUI
import Combine

/// Main router class that manages navigation and route matching
/// Equivalent to GoRouter in Flutter's GoRouter
@MainActor
public class RouteKit: ObservableObject {
    
    // MARK: - Properties
    
    /// The configured routes
    public let routes: [Route]
    
    /// The initial route path
    public let initialRoute: String
    
    /// Current navigation path
    @Published public private(set) var currentPath: String
    
    /// Current route context
    @Published public private(set) var currentContext: RouteContext
    
    /// Navigation history stack
    @Published public private(set) var navigationStack: [String]
    
    /// Error builder for handling routing errors
    public let errorBuilder: ((Error) -> AnyView)?
    
    /// Redirect callback for global redirects
    public let redirect: ((RouteContext) -> String?)?
    
    /// Debug logging enabled
    public let debugLogDiagnostics: Bool
    
    /// Maximum number of redirects before stopping
    private let redirectLimit: Int
    
    /// All routes flattened for easier lookup
    private let flatRoutes: [Route]
    
    /// Named routes lookup
    private let namedRoutes: [String: Route]
    
    // MARK: - Initialization
    
    public init(
        routes: [Route],
        initialRoute: String = "/",
        errorBuilder: ((Error) -> AnyView)? = nil,
        redirect: ((RouteContext) -> String?)? = nil,
        debugLogDiagnostics: Bool = false,
        redirectLimit: Int = 5
    ) {
        self.routes = routes
        self.initialRoute = initialRoute
        self.errorBuilder = errorBuilder
        self.redirect = redirect
        self.debugLogDiagnostics = debugLogDiagnostics
        self.redirectLimit = redirectLimit
        
        // Flatten routes for efficient lookup
        self.flatRoutes = routes.flatMap { $0.allRoutes }
        
        // Build named routes lookup
        self.namedRoutes = Dictionary(
            flatRoutes.compactMap { route in
                guard let name = route.name else { return nil }
                return (name, route)
            },
            uniquingKeysWith: { first, _ in first }
        )
        
        // Initialize with the initial route
        let initialContext = RouteContext(fullPath: initialRoute)
        self.currentPath = initialRoute
        self.currentContext = initialContext
        self.navigationStack = [initialRoute]
    }
    
    // MARK: - Public Navigation Methods
    
    /// Navigate to a path, replacing the current route stack
    public func go(_ path: String, extra: Any? = nil) {
        _navigateToPath(path, extra: extra, replace: true)
    }
    
    /// Push a new route onto the navigation stack
    public func push(_ path: String, extra: Any? = nil) {
        _navigateToPath(path, extra: extra, replace: false)
    }
    
    /// Pop the current route from the navigation stack
    public func pop() {
        guard navigationStack.count > 1 else {
            log("Cannot pop: only one route in stack")
            return
        }
        
        navigationStack.removeLast()
        let previousPath = navigationStack.last!
        _navigateToPath(previousPath, replace: true, updateStack: false)
    }
    
    /// Navigate to a named route
    public func goNamed(
        _ name: String,
        pathParameters: [String: String] = [:],
        queryParameters: [String: String] = [:],
        extra: Any? = nil
    ) {
        guard let route = namedRoutes[name] else {
            handleError(RoutingError.routeNotFound("Named route '\(name)' not found"))
            return
        }
        
        let path = buildPathFromPattern(route.path, pathParameters: pathParameters, queryParameters: queryParameters)
        go(path, extra: extra)
    }
    
    /// Push a named route onto the navigation stack
    public func pushNamed(
        _ name: String,
        pathParameters: [String: String] = [:],
        queryParameters: [String: String] = [:],
        extra: Any? = nil
    ) {
        guard let route = namedRoutes[name] else {
            handleError(RoutingError.routeNotFound("Named route '\(name)' not found"))
            return
        }
        
        let path = buildPathFromPattern(route.path, pathParameters: pathParameters, queryParameters: queryParameters)
        push(path, extra: extra)
    }
    
    /// Get the location for a named route
    public func namedLocation(
        _ name: String,
        pathParameters: [String: String] = [:],
        queryParameters: [String: String] = [:]
    ) -> String? {
        guard let route = namedRoutes[name] else {
            return nil
        }
        
        return buildPathFromPattern(route.path, pathParameters: pathParameters, queryParameters: queryParameters)
    }
    
    /// Handle deep links from the platform
    public func handleDeepLink(_ url: URL) {
        let path = url.path.isEmpty ? "/" : url.path
        go(path)
    }
    
    // MARK: - Private Methods
    
    private func _navigateToPath(_ path: String, extra: Any? = nil, replace: Bool, updateStack: Bool = true) {
        let normalizedPath = URLParser.normalizePath(path)
        log("Navigating to: \(normalizedPath)")
        
        // Handle redirects
        var finalPath = normalizedPath
        var redirectCount = 0
        
        while redirectCount < redirectLimit {
            let tempContext = RouteContext(fullPath: finalPath, extra: extra)
            
            // Check global redirect first
            if let globalRedirect = redirect?(tempContext) {
                finalPath = URLParser.normalizePath(globalRedirect)
                redirectCount += 1
                log("Global redirect to: \(finalPath)")
                continue
            }
            
            // Check route-specific redirect
            if let match = findMatchingRoute(for: finalPath),
               let routeRedirect = match.route.redirect {
                let context = RouteContext(
                    fullPath: finalPath,
                    matchedPath: match.matchedPath,
                    pathParameters: match.pathParameters,
                    extra: extra,
                    name: match.route.name
                )
                
                if let redirectPath = routeRedirect(context) {
                    finalPath = URLParser.normalizePath(redirectPath)
                    redirectCount += 1
                    log("Route redirect to: \(finalPath)")
                    continue
                }
            }
            
            break
        }
        
        if redirectCount >= redirectLimit {
            handleError(RoutingError.redirectLoop(redirectCount))
            return
        }
        
        // Find matching route
        guard let match = findMatchingRoute(for: finalPath) else {
            handleError(RoutingError.routeNotFound(finalPath))
            return
        }
        
        // Check route guard
        let context = RouteContext(
            fullPath: finalPath,
            matchedPath: match.matchedPath,
            pathParameters: match.pathParameters,
            extra: extra,
            name: match.route.name,
            navigationStack: navigationStack
        )
        
        if let routeGuard = match.route.routeGuard, !routeGuard(context) {
            handleError(RoutingError.guardRejected(finalPath))
            return
        }
        
        // Update navigation state
        if updateStack {
            if replace {
                if navigationStack.isEmpty {
                    navigationStack = [finalPath]
                } else {
                    navigationStack[navigationStack.count - 1] = finalPath
                }
            } else {
                navigationStack.append(finalPath)
            }
        }
        
        currentPath = finalPath
        currentContext = context
        
        log("Navigation successful to: \(finalPath)")
    }
    
    private func findMatchingRoute(for path: String) -> RouteMatch? {
        // Try exact matches first
        for route in flatRoutes {
            if let match = route.matches(path: path) {
                return RouteMatch(
                    route: route,
                    pathParameters: match.pathParameters,
                    matchedPath: match.matchedPath,
                    remainingPath: match.remainingPath
                )
            }
        }
        return nil
    }
    
    private func buildPathFromPattern(_ pattern: String, pathParameters: [String: String], queryParameters: [String: String]) -> String {
        var path = pattern
        
        // Replace path parameters
        for (key, value) in pathParameters {
            path = path.replacingOccurrences(of: ":\(key)", with: value)
        }
        
        // Add query parameters
        if !queryParameters.isEmpty {
            let queryString = queryParameters
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "&")
            path += "?\(queryString)"
        }
        
        return path
    }
    
    private func handleError(_ error: Error) {
        log("Routing error: \(error)")
        
        if errorBuilder != nil {
            let errorContext = RouteContext(
                fullPath: currentPath,
                error: error
            )
            currentContext = errorContext
        } else {
            // Use default error handling
            print("RouteKit Error: \(error)")
        }
    }
    
    private func log(_ message: String) {
        if debugLogDiagnostics {
            print("[RouteKit] \(message)")
        }
    }
}

// MARK: - Routing Errors

public enum RoutingError: Error, LocalizedError {
    case routeNotFound(String)
    case invalidParameters([String: String])
    case redirectLoop(Int)
    case guardRejected(String)
    
    public var errorDescription: String? {
        switch self {
        case .routeNotFound(let path):
            return "Route not found for path: \(path)"
        case .invalidParameters(let params):
            return "Invalid parameters: \(params)"
        case .redirectLoop(let count):
            return "Redirect loop detected after \(count) redirects"
        case .guardRejected(let path):
            return "Route guard rejected navigation to: \(path)"
        }
    }
}
