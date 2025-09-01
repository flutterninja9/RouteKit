import Foundation
import SwiftUI

/// Enhanced navigation controller for complex routing patterns
/// Provides advanced route matching and shell-aware navigation
@MainActor
public class NavigationController: ObservableObject {
    
    /// The router instance
    public weak var router: RouteKit?
    
    /// Nested route manager for hierarchical navigation
    private let nestedRouteManager: NestedRouteManager
    
    public init(router: RouteKit) {
        self.router = router
        self.nestedRouteManager = NestedRouteManager(routes: router.routes)
    }
    
    /// Find the best matching route for a given path, considering nesting
    func findBestMatch(for path: String) -> RouteMatch? {
        guard let router = router else { return nil }
        
        // Try direct matches across all known routes first
        for route in router.allRoutes {
            if let match = route.matches(path: path) {
                router.currentShell = nil
                router.currentStatefulShell = nil
                return match
            }
        }
        
        // Try stateful shell routes with enhanced matching
        for statefulShell in router.statefulShellRoutes {
            for (branchIndex, branch) in statefulShell.branches.enumerated() {
                if let route = nestedRouteManager.findBestMatch(for: path, in: branch.routes) {
                    if let match = route.matches(path: path) {
                        // Update the shell's current branch
                        router.currentStatefulShell?.updateCurrentIndex(branchIndex)
                        return match
                    }
                }
            }
        }
        
        // Try shell routes with enhanced matching
        for shell in router.shellRoutes {
            if let route = nestedRouteManager.findBestMatch(for: path, in: shell.routes) {
                if let match = route.matches(path: path) {
                    router.currentShell = shell
                    return match
                }
            }
        }
        
        return nil
    }
    
    /// Get child routes for a given parent path
    public func findChildRoutes(for parentPath: String) -> [Route] {
        guard let router = router else { return [] }
    return nestedRouteManager.findChildRoutes(for: parentPath, in: router.allRoutes)
    }
    
    /// Check if a route is a child of another route
    public func isChildRoute(_ childPath: String, of parentPath: String) -> Bool {
        return nestedRouteManager.isChildRoute(childPath, of: parentPath)
    }
    
    /// Get breadcrumbs for the current navigation state
    public func getBreadcrumbs() -> [String] {
        guard let router = router else { return [] }
        return NestedRouteManager.buildBreadcrumbs(for: router.currentPath)
    }
    
    /// Get the parent path of the current route
    public func getParentPath() -> String? {
        guard let router = router else { return nil }
        return NestedRouteManager.getParentPath(router.currentPath)
    }
    
    /// Navigate to the parent route if available
    public func navigateToParent() {
        guard let parentPath = getParentPath() else { return }
        navigate(to: parentPath)
    }
    
    /// Check if current route has children
    public func hasChildRoutes() -> Bool {
        guard let router = router else { return false }
        return !findChildRoutes(for: router.currentPath).isEmpty
    }
    
    /// Get the depth of the current route
    public func getCurrentDepth() -> Int {
        guard let router = router else { return 0 }
        return NestedRouteManager.getRouteDepth(router.currentPath)
    }
    
    /// Navigate with enhanced route resolution
    func navigate(to path: String, extra: (any Sendable)? = nil, replace: Bool = true) {
        guard let router = router else { return }
        
        let normalizedPath = URLParser.normalizePath(path)
        
        // Find the best matching route
        guard let match = findBestMatch(for: normalizedPath) else {
            router.handleError(RoutingError.routeNotFound(normalizedPath))
            return
        }
        
        // Create enhanced context
        let context = RouteContext(
            fullPath: normalizedPath,
            matchedPath: match.matchedPath,
            pathParameters: match.pathParameters,
            extra: extra,
            name: match.route.name,
            navigationStack: router.navigationStack
        )
        
        // Check route guard
        if let routeGuard = match.route.routeGuard, !routeGuard(context) {
            router.handleError(RoutingError.guardRejected(normalizedPath))
            return
        }
        
        // Handle redirection
        if let redirect = match.route.redirect,
           let redirectPath = redirect(context) {
            navigate(to: redirectPath, extra: extra, replace: replace)
            return
        }
        
        // Update navigation state
        updateNavigationState(path: normalizedPath, context: context, replace: replace)
    }
    
    /// Update the navigation state based on the current navigation context
    private func updateNavigationState(path: String, context: RouteContext, replace: Bool) {
        guard let router = router else { return }
        
        // Update navigation stack
        if replace {
            if router.navigationStack.isEmpty {
                router.updateNavigationStack([path])
            } else {
                var newStack = router.navigationStack
                newStack[newStack.count - 1] = path
                router.updateNavigationStack(newStack)
            }
        } else {
            router.appendToNavigationStack(path)
        }
        
        // Update current state
        router.updateCurrentPath(path)
        router.updateCurrentContext(context)
        
        // Update shell-specific navigation state
        if let statefulShell = router.currentStatefulShell {
            updateStatefulShellState(shell: statefulShell, path: path, replace: replace)
        }
    }
    
    /// Update stateful shell navigation state
    private func updateStatefulShellState(shell: StatefulNavigationShell, path: String, replace: Bool) {
        let currentIndex = shell.currentIndex
        guard currentIndex < shell.branchStacks.count else { return }
        
        if replace {
            shell.updateBranchStack(at: currentIndex, with: [path])
        } else {
            shell.appendToBranchStack(at: currentIndex, path: path)
        }
    }
    
    /// Handle pop navigation with shell awareness
    func pop() {
        guard let router = router else { return }
        
        // Handle stateful shell pop
        if let statefulShell = router.currentStatefulShell {
            if statefulShell.canPop {
                statefulShell.pop()
                return
            }
        }
        
        // Handle regular pop
        guard router.navigationStack.count > 1 else { return }
        
        router.removeLastFromNavigationStack()
        let previousPath = router.navigationStack.last!
        navigate(to: previousPath, replace: true)
    }
    
    /// Navigate to a specific branch in a stateful shell
    func navigateToBranch(_ index: Int, resetStack: Bool = false) {
        guard let router = router,
              let statefulShell = router.currentStatefulShell else { return }
        
        statefulShell.goBranch(index, resetStack: resetStack)
    }
    
    /// Build a path from a pattern and parameters
    func buildPath(from pattern: String, pathParameters: [String: String] = [:], queryParameters: [String: String] = [:]) -> String {
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
}

// MARK: - Enhanced Route Matching

extension Route {
    /// Enhanced route matching that considers nested structure
    internal func enhancedMatch(path: String, basePath: String = "") -> RouteMatch? {
        let fullPattern = basePath.isEmpty ? self.path : "\(basePath)\(self.path)"
        let pattern = RoutePattern(fullPattern)
        
        if let match = pattern.match(path, route: self) {
            return RouteMatch(
                route: self,
                pathParameters: match.pathParameters,
                matchedPath: match.matchedPath,
                remainingPath: match.remainingPath
            )
        }
        
        // Check child routes with current path as base
        for childRoute in routes {
            if let childMatch = childRoute.enhancedMatch(path: path, basePath: fullPattern) {
                return childMatch
            }
        }
        
        return nil
    }
}

// MARK: - Navigation Helpers

extension RouteKit {
    /// Get the navigation controller
    internal var navigationController: NavigationController {
        return NavigationController(router: self)
    }
    
    /// Enhanced navigation method using the navigation controller
    internal func enhancedNavigate(to path: String, extra: (any Sendable)? = nil, replace: Bool = true) {
        navigationController.navigate(to: path, extra: extra, replace: replace)
    }
    
    /// Enhanced pop using the navigation controller
    internal func enhancedPop() {
        navigationController.pop()
    }
}
