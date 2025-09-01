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
    
    /// The configured shell routes
    public let shellRoutes: [ShellRoute]
    
    /// The configured stateful shell routes
    public let statefulShellRoutes: [StatefulShellRoute]
    
    /// The initial route path
    public let initialRoute: String
    
    /// Current navigation path
    @Published public private(set) var currentPath: String
    
    /// Current route context
    @Published public private(set) var currentContext: RouteContext
    
    /// Navigation history stack
    @Published public private(set) var navigationStack: [String]
    
    /// Current shell (if navigating within a shell)
    @Published public internal(set) var currentShell: ShellRoute?
    
    /// Current stateful shell (if navigating within a stateful shell)
    @Published public internal(set) var currentStatefulShell: StatefulNavigationShell?
    
    /// Error builder for handling routing errors
    public let errorBuilder: ((Error) -> AnyView)?
    
    /// Redirect callback for global redirects
    public let redirect: ((RouteContext) -> String?)?
    
    /// Debug logging enabled
    public let debugLogDiagnostics: Bool
    
    /// Guard and middleware manager
    @Published public internal(set) var guardMiddlewareManager: GuardMiddlewareManager
    
    /// Maximum number of redirects before stopping
    private let redirectLimit: Int
    
    /// All routes flattened for easier lookup
    private let flatRoutes: [Route]
    
    /// Named routes lookup
    private let namedRoutes: [String: Route]
    
    /// Expose all routes (flattened) for internal consumers like NavigationController/tests
    internal var allRoutes: [Route] { flatRoutes }
    
    // MARK: - Initialization
    
    public init(
        routes: [Route] = [],
        shellRoutes: [ShellRoute] = [],
        statefulShellRoutes: [StatefulShellRoute] = [],
        initialRoute: String = "/",
        errorBuilder: ((Error) -> AnyView)? = nil,
        redirect: ((RouteContext) -> String?)? = nil,
        debugLogDiagnostics: Bool = false,
        redirectLimit: Int = 5
    ) {
        self.routes = routes
        self.shellRoutes = shellRoutes
        self.statefulShellRoutes = statefulShellRoutes
        self.initialRoute = initialRoute
        self.errorBuilder = errorBuilder
        self.redirect = redirect
        self.debugLogDiagnostics = debugLogDiagnostics
        self.redirectLimit = redirectLimit
        
        // Flatten routes for efficient lookup (including shell routes)
        var allRoutes = routes.flatMap { $0.allRoutes }
        allRoutes.append(contentsOf: shellRoutes.flatMap { $0.allRoutes })
        allRoutes.append(contentsOf: statefulShellRoutes.flatMap { $0.allRoutes })
        self.flatRoutes = allRoutes
        
        // Build named routes lookup
        self.namedRoutes = Dictionary(
            flatRoutes.compactMap { route in
                guard let name = route.name else { return nil }
                return (name, route)
            },
            uniquingKeysWith: { first, _ in first }
        )
        
        // Initialize with the initial route
        let initialComponents = URLComponents(string: initialRoute) ?? URLComponents()
        let queryParams = initialComponents.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        } ?? [:]
        
        let initialContext = RouteContext(
            fullPath: initialRoute,
            queryParameters: queryParams
        )
        self.currentPath = initialRoute
        self.currentContext = initialContext
        self.navigationStack = [initialRoute]
        
        // Initialize shell states
        self.currentShell = nil
        
        // Initialize stateful shell (create the first one if available)
        if let firstStatefulShellRoute = statefulShellRoutes.first {
            self.currentStatefulShell = StatefulNavigationShell(branches: firstStatefulShellRoute.branches, router: nil)
        } else {
            self.currentStatefulShell = nil
        }
        
        // Initialize guard and middleware manager
        self.guardMiddlewareManager = GuardMiddlewareManager()
        self.guardMiddlewareManager.debugEnabled = debugLogDiagnostics
        
        // Register route-specific guards and middleware
        for route in flatRoutes {
            for routeGuard in route.guards {
                guardMiddlewareManager.addGuard(routeGuard, for: route.path)
            }
            for middleware in route.middleware {
                guardMiddlewareManager.addMiddleware(middleware, for: route.path)
            }
        }
        
        // Set router reference for stateful shell after initialization
        DispatchQueue.main.async { [weak self] in
            self?.currentStatefulShell?.router = self
        }
    }
    
    // MARK: - Public Navigation Methods
    
    /// Navigate to a path, replacing the current route stack
    public func go(_ path: String, extra: (any Sendable)? = nil) {
        _navigateToPath(path, extra: extra, replace: true)
    }
    
    /// Push a new route onto the navigation stack
    public func push(_ path: String, extra: (any Sendable)? = nil) {
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
        extra: (any Sendable)? = nil
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
        extra: (any Sendable)? = nil
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
    
    // MARK: - Guards and Middleware Management
    
    /// Add a global guard that applies to all routes
    public func addGlobalGuard(_ routeGuard: RouteGuard) {
        guardMiddlewareManager.addGlobalGuard(routeGuard)
    }
    
    /// Add a guard for a specific route pattern
    public func addGuard(_ routeGuard: RouteGuard, for routePattern: String) {
        guardMiddlewareManager.addGuard(routeGuard, for: routePattern)
    }
    
    /// Add global middleware that applies to all routes
    public func addGlobalMiddleware(_ middleware: RouteMiddleware) {
        guardMiddlewareManager.addGlobalMiddleware(middleware)
    }
    
    /// Add middleware for a specific route pattern
    public func addMiddleware(_ middleware: RouteMiddleware, for routePattern: String) {
        guardMiddlewareManager.addMiddleware(middleware, for: routePattern)
    }
    
    /// Remove guards for a specific route pattern
    public func removeGuards(for routePattern: String) {
        guardMiddlewareManager.removeGuards(for: routePattern)
    }
    
    /// Remove middleware for a specific route pattern
    public func removeMiddleware(for routePattern: String) {
        guardMiddlewareManager.removeMiddleware(for: routePattern)
    }
    
    /// Clear all global guards
    public func clearGlobalGuards() {
        guardMiddlewareManager.clearGlobalGuards()
    }
    
    /// Clear all global middleware
    public func clearGlobalMiddleware() {
        guardMiddlewareManager.clearGlobalMiddleware()
    }
    
    // MARK: - Private Methods
    
    private func _navigateToPath(_ path: String, extra: (any Sendable)? = nil, replace: Bool, updateStack: Bool = true) {
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
        
        // Parse query parameters from the final path
        let components = URLComponents(string: finalPath) ?? URLComponents()
        let queryParams = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        } ?? [:]
        
        // Create route context for guard and middleware execution
        let routeContext = RouteContext(
            fullPath: finalPath,
            matchedPath: match.matchedPath,
            pathParameters: match.pathParameters,
            queryParameters: queryParams,
            extra: extra,
            name: match.route.name,
            navigationStack: navigationStack
        )
        
    // Optimistically update current path/context so synchronous queries (breadcrumbs/parent/depth) reflect intent.
    // The final validated navigation (after guards/middleware) will reconcile state if redirected/denied.
    // Only update the simple path/context here; maintain stack changes until completion to avoid duplications.
    currentPath = routeContext.fullPath
    currentContext = routeContext
        
    // Execute guards and middleware asynchronously
    Task { @MainActor in
            await executeGuardsAndMiddleware(for: routeContext, route: match.route, replace: replace, updateStack: updateStack)
        }
    }
    
    /// Execute guards and middleware for a route
    private func executeGuardsAndMiddleware(for context: RouteContext, route: Route, replace: Bool, updateStack: Bool) async {
        // Check legacy route guard first (for backward compatibility)
        if let routeGuard = route.routeGuard, !routeGuard(context) {
            handleError(RoutingError.guardRejected(context.fullPath))
            return
        }
        
        // Execute new guards system
        let guardResult = await guardMiddlewareManager.executeGuards(for: context)
        
        switch guardResult {
        case .allow(let allowedContext):
            // Guards passed, now execute middleware
            let middlewareResult = await guardMiddlewareManager.executeMiddleware(for: allowedContext)
            
            switch middlewareResult {
            case .proceed(let finalContext):
                // All checks passed, proceed with navigation
                await completeNavigation(context: finalContext, route: route, replace: replace, updateStack: updateStack)
                
            case .redirect(let redirectPath):
                log("Middleware redirected to: \(redirectPath)")
                _navigateToPath(redirectPath, extra: context.extra, replace: replace, updateStack: updateStack)
                
            case .error(let error):
                log("Middleware failed: \(error)")
                handleError(error)
            }
            
        case .deny(let error):
            log("Guard denied navigation: \(error)")
            handleError(error)
            
        case .redirect(let redirectPath):
            log("Guard redirected to: \(redirectPath)")
            _navigateToPath(redirectPath, extra: context.extra, replace: replace, updateStack: updateStack)
            
        case .error(let error):
            log("Guard failed: \(error)")
            handleError(error)
        }
    }
    
    /// Complete the navigation after all guards and middleware have passed
    private func completeNavigation(context: RouteContext, route: Route, replace: Bool, updateStack: Bool) async {
        // Update navigation state
        if updateStack {
            if replace {
                if navigationStack.isEmpty {
                    navigationStack = [context.fullPath]
                } else {
                    navigationStack[navigationStack.count - 1] = context.fullPath
                }
            } else {
                navigationStack.append(context.fullPath)
            }
        }
        
        currentPath = context.fullPath
        currentContext = context
        
        // Notify middleware that the route has been activated
        await guardMiddlewareManager.notifyRouteActivated(context: context)
        
        log("Navigation successful to: \(context.fullPath)")
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
    
    internal func handleError(_ error: Error) {
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
    
    // MARK: - Internal State Updates
    
    /// Update the current path (internal use)
    internal func updateCurrentPath(_ path: String) {
        currentPath = path
    }
    
    /// Update the current context (internal use)  
    internal func updateCurrentContext(_ context: RouteContext) {
        currentContext = context
    }
    
    /// Update the navigation stack (internal use)
    internal func updateNavigationStack(_ stack: [String]) {
        navigationStack = stack
    }
    
    /// Append to navigation stack (internal use)
    internal func appendToNavigationStack(_ path: String) {
        navigationStack.append(path)
    }
    
    /// Remove last from navigation stack (internal use)
    internal func removeLastFromNavigationStack() {
        if navigationStack.count > 1 {
            navigationStack.removeLast()
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
