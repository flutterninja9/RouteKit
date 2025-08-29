import Foundation
import SwiftUI

/// Manager for route guards and middleware
@MainActor
public class GuardMiddlewareManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Global guards that apply to all routes
    private var globalGuards: [RouteGuard] = []
    
    /// Global middleware that applies to all routes
    private var globalMiddleware: [RouteMiddleware] = []
    
    /// Route-specific guards
    private var routeGuards: [String: [RouteGuard]] = [:]
    
    /// Route-specific middleware
    private var routeMiddleware: [String: [RouteMiddleware]] = [:]
    
    /// Guard execution timeout in seconds
    public var guardTimeout: TimeInterval = 5.0
    
    /// Middleware execution timeout in seconds
    public var middlewareTimeout: TimeInterval = 10.0
    
    /// Enable debug logging
    public var debugEnabled: Bool = false
    
    // MARK: - Global Guards Management
    
    /// Add a global guard that applies to all routes
    public func addGlobalGuard(_ guard: RouteGuard) {
        globalGuards.append(`guard`)
        log("Added global guard: \(`guard`.name)")
    }
    
    /// Remove a global guard by name
    public func removeGlobalGuard(name: String) {
        globalGuards.removeAll { $0.name == name }
        log("Removed global guard: \(name)")
    }
    
    /// Clear all global guards
    public func clearGlobalGuards() {
        let count = globalGuards.count
        globalGuards.removeAll()
        log("Cleared \(count) global guards")
    }
    
    // MARK: - Global Middleware Management
    
    /// Add global middleware that applies to all routes
    public func addGlobalMiddleware(_ middleware: RouteMiddleware) {
        globalMiddleware.append(middleware)
        log("Added global middleware: \(middleware.name)")
    }
    
    /// Remove global middleware by name
    public func removeGlobalMiddleware(name: String) {
        globalMiddleware.removeAll { $0.name == name }
        log("Removed global middleware: \(name)")
    }
    
    /// Clear all global middleware
    public func clearGlobalMiddleware() {
        let count = globalMiddleware.count
        globalMiddleware.removeAll()
        log("Cleared \(count) global middleware")
    }
    
    // MARK: - Route-Specific Guards Management
    
    /// Add a guard for a specific route
    public func addGuard(_ guard: RouteGuard, for route: String) {
        if routeGuards[route] == nil {
            routeGuards[route] = []
        }
        routeGuards[route]?.append(`guard`)
        log("Added guard '\(`guard`.name)' for route: \(route)")
    }
    
    /// Remove guards for a specific route
    public func removeGuards(for route: String) {
        let count = routeGuards[route]?.count ?? 0
        routeGuards.removeValue(forKey: route)
        log("Removed \(count) guards for route: \(route)")
    }
    
    /// Remove a specific guard from a route
    public func removeGuard(name: String, from route: String) {
        routeGuards[route]?.removeAll { $0.name == name }
        log("Removed guard '\(name)' from route: \(route)")
    }
    
    // MARK: - Route-Specific Middleware Management
    
    /// Add middleware for a specific route
    public func addMiddleware(_ middleware: RouteMiddleware, for route: String) {
        if routeMiddleware[route] == nil {
            routeMiddleware[route] = []
        }
        routeMiddleware[route]?.append(middleware)
        log("Added middleware '\(middleware.name)' for route: \(route)")
    }
    
    /// Remove middleware for a specific route
    public func removeMiddleware(for route: String) {
        let count = routeMiddleware[route]?.count ?? 0
        routeMiddleware.removeValue(forKey: route)
        log("Removed \(count) middleware for route: \(route)")
    }
    
    /// Remove a specific middleware from a route
    public func removeMiddleware(name: String, from route: String) {
        routeMiddleware[route]?.removeAll { $0.name == name }
        log("Removed middleware '\(name)' from route: \(route)")
    }
    
    // MARK: - Execution Methods
    
    /// Execute all applicable guards for a route
    public func executeGuards(for context: RouteContext) async -> GuardExecutionResult {
        let allGuards = getAllGuards(for: context.fullPath)
        
        if allGuards.isEmpty {
            return .allow(context)
        }
        
        log("Executing \(allGuards.count) guards for: \(context.fullPath)")
        
        for routeGuard in allGuards {
            let result = await routeGuard.canActivate(context: context)
            
            switch result {
            case .allow:
                log("Guard '\(routeGuard.name)' allowed navigation")
                continue
            case .allowWithModification(let newContext):
                log("Guard '\(routeGuard.name)' allowed with modification")
                return .allow(newContext)
            case .deny:
                log("Guard '\(routeGuard.name)' denied navigation")
                return .deny(GuardError.accessDenied("Access denied by \(routeGuard.name)"))
            case .redirect(let path):
                log("Guard '\(routeGuard.name)' redirecting to: \(path)")
                return .redirect(path)
            case .error(let error):
                log("Guard '\(routeGuard.name)' failed with error: \(error)")
                return .error(error)
            }
        }
        
        return .allow(context)
    }
    
    /// Execute all applicable middleware for a route
    public func executeMiddleware(for context: RouteContext) async -> MiddlewareExecutionResult {
        let allMiddleware = getAllMiddleware(for: context.fullPath)
        
        if allMiddleware.isEmpty {
            return .proceed(context)
        }
        
        log("Executing \(allMiddleware.count) middleware for: \(context.fullPath)")
        
        var currentContext = context
        
        for middleware in allMiddleware {
            let result = await middleware.process(context: currentContext)
            
            switch result {
            case .proceed(let newContext):
                log("Middleware '\(middleware.name)' proceeding")
                currentContext = newContext
            case .modified(let newContext):
                log("Middleware '\(middleware.name)' modified context")
                currentContext = newContext
            case .redirect(let path):
                log("Middleware '\(middleware.name)' redirecting to: \(path)")
                return .redirect(path)
            case .error(let error):
                log("Middleware '\(middleware.name)' failed with error: \(error)")
                return .error(error)
            }
        }
        
        return .proceed(currentContext)
    }
    
    /// Notify middleware that a route has been activated
    public func notifyRouteActivated(context: RouteContext) async {
        let allMiddleware = getAllMiddleware(for: context.fullPath)
        
        for middleware in allMiddleware {
            await middleware.onRouteActivated(context: context)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAllGuards(for path: String) -> [RouteGuard] {
        var guards = globalGuards
        
        // Add route-specific guards
        for (routePath, routeGuards) in routeGuards {
            if pathMatches(path: path, pattern: routePath) {
                guards.append(contentsOf: routeGuards)
            }
        }
        
        return guards
    }
    
    private func getAllMiddleware(for path: String) -> [RouteMiddleware] {
        var middleware = globalMiddleware
        
        // Add route-specific middleware
        for (routePath, routeMiddleware) in routeMiddleware {
            if pathMatches(path: path, pattern: routePath) {
                middleware.append(contentsOf: routeMiddleware)
            }
        }
        
        return middleware
    }
    
    private func pathMatches(path: String, pattern: String) -> Bool {
        // Simple pattern matching - could be enhanced with more sophisticated logic
        if pattern == "*" {
            return true
        }
        
        if pattern.contains("*") {
            let regex = pattern.replacingOccurrences(of: "*", with: ".*")
            return path.range(of: "^\(regex)$", options: .regularExpression) != nil
        }
        
        return path == pattern
    }
    
    private func log(_ message: String) {
        if debugEnabled {
            print("[GuardMiddlewareManager] \(message)")
        }
    }
}

// MARK: - Result Types

/// Result of guard execution
public enum GuardExecutionResult {
    case allow(RouteContext)
    case deny(Error)
    case redirect(String)
    case error(Error)
}

/// Result of middleware execution
public enum MiddlewareExecutionResult {
    case proceed(RouteContext)
    case redirect(String)
    case error(Error)
}
