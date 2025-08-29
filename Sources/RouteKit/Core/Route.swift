import Foundation
import SwiftUI

/// A route definition that specifies how to handle a URL path
/// Equivalent to GoRoute in Flutter's GoRouter
public struct Route {
    /// The path pattern for this route (e.g., "/users/:userId")
    public let path: String
    
    /// Optional name for this route for named navigation
    public let name: String?
    
    /// Builder function that creates the view for this route
    public let builder: (RouteContext) -> AnyView
    
    /// Child routes nested under this route
    public let routes: [Route]
    
    /// Redirect function for conditional navigation
    public let redirect: ((RouteContext) -> String?)?
    
    /// Route guard for access control
    public let routeGuard: ((RouteContext) -> Bool)?
    
    public init(
        path: String,
        name: String? = nil,
        routes: [Route] = [],
        redirect: ((RouteContext) -> String?)? = nil,
        routeGuard: ((RouteContext) -> Bool)? = nil,
        @ViewBuilder builder: @escaping (RouteContext) -> some View
    ) {
        self.path = path
        self.name = name
        self.routes = routes
        self.redirect = redirect
        self.routeGuard = routeGuard
        self.builder = { context in AnyView(builder(context)) }
    }
    
    /// Convenience initializer for simple routes without child routes
    public init(
        path: String,
        name: String? = nil,
        redirect: ((RouteContext) -> String?)? = nil,
        routeGuard: ((RouteContext) -> Bool)? = nil,
        @ViewBuilder builder: @escaping (RouteContext) -> some View
    ) {
        self.init(
            path: path,
            name: name,
            routes: [],
            redirect: redirect,
            routeGuard: routeGuard,
            builder: builder
        )
    }
}

// MARK: - Route Matching
extension Route {
    /// Check if this route matches the given path
    internal func matches(path: String) -> RouteMatch? {
        return RoutePattern(self.path).match(path)
    }
    
    /// Get all routes including nested routes in a flat list
    internal var allRoutes: [Route] {
        var result = [self]
        for childRoute in routes {
            result.append(contentsOf: childRoute.allRoutes)
        }
        return result
    }
}

/// Result of matching a route pattern against a path
internal struct RouteMatch {
    let route: Route
    let pathParameters: [String: String]
    let matchedPath: String
    let remainingPath: String
    
    init(route: Route, pathParameters: [String: String] = [:], matchedPath: String, remainingPath: String = "") {
        self.route = route
        self.pathParameters = pathParameters
        self.matchedPath = matchedPath
        self.remainingPath = remainingPath
    }
}

/// Pattern matching for route paths
internal struct RoutePattern {
    let pattern: String
    private let segments: [PatternSegment]
    
    init(_ pattern: String) {
        self.pattern = pattern
        self.segments = Self.parsePattern(pattern)
    }
    
    func match(_ path: String) -> RouteMatch? {
        let pathSegments = path.split(separator: "/").map(String.init)
        let patternSegments = self.segments
        
        // Handle root path
        if pattern == "/" && path == "/" {
            return RouteMatch(route: Route(path: "/", builder: { _ in EmptyView() }), matchedPath: "/")
        }
        
        var parameters: [String: String] = [:]
        var matchedSegments: [String] = []
        
        for (index, patternSegment) in patternSegments.enumerated() {
            guard index < pathSegments.count else {
                // Not enough path segments to match
                return nil
            }
            
            let pathSegment = pathSegments[index]
            
            switch patternSegment {
            case .literal(let literal):
                if pathSegment != literal {
                    return nil
                }
                matchedSegments.append(pathSegment)
                
            case .parameter(let paramName):
                parameters[paramName] = pathSegment
                matchedSegments.append(pathSegment)
            }
        }
        
        // Check if we matched all pattern segments
        guard patternSegments.count <= pathSegments.count else {
            return nil
        }
        
        let matchedPath = "/" + matchedSegments.joined(separator: "/")
        let remainingSegments = Array(pathSegments.dropFirst(patternSegments.count))
        let remainingPath = remainingSegments.isEmpty ? "" : "/" + remainingSegments.joined(separator: "/")
        
        return RouteMatch(
            route: Route(path: pattern, builder: { _ in EmptyView() }),
            pathParameters: parameters,
            matchedPath: matchedPath,
            remainingPath: remainingPath
        )
    }
    
    private static func parsePattern(_ pattern: String) -> [PatternSegment] {
        let segments = pattern.split(separator: "/").map(String.init)
        return segments.map { segment in
            if segment.hasPrefix(":") {
                let paramName = String(segment.dropFirst())
                return .parameter(paramName)
            } else {
                return .literal(segment)
            }
        }
    }
}

private enum PatternSegment {
    case literal(String)
    case parameter(String)
}
