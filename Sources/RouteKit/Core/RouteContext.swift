import Foundation
import SwiftUI

/// Route context containing navigation state and parameters
/// Equivalent to GoRouterState in Flutter's GoRouter
public struct RouteContext: Sendable {
    /// The full URL path that was matched
    public let fullPath: String
    
    /// The route path pattern that matched
    public let matchedPath: String
    
    /// Path parameters extracted from the URL
    public let pathParameters: [String: String]
    
    /// Query parameters from the URL
    public let queryParameters: [String: String]
    
    /// Additional data passed during navigation
    public let extra: (any Sendable)?
    
    /// The route name if it was named
    public let name: String?
    
    /// Navigation history for this route
    public let navigationStack: [String]
    
    /// Error information if this route represents an error state
    public let error: Error?
    
    /// The URI components for advanced URL manipulation
    public let uri: URLComponents
    
    public init(
        fullPath: String,
        matchedPath: String = "",
        pathParameters: [String: String] = [:],
        queryParameters: [String: String] = [:],
        extra: (any Sendable)? = nil,
        name: String? = nil,
        navigationStack: [String] = [],
        error: Error? = nil
    ) {
        self.fullPath = fullPath
        self.matchedPath = matchedPath
        self.pathParameters = pathParameters
        self.queryParameters = queryParameters
        self.extra = extra
        self.name = name
        self.navigationStack = navigationStack
        self.error = error
        
        // Parse URI components
        var components = URLComponents()
        components.path = fullPath
        if !queryParameters.isEmpty {
            components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        self.uri = components
    }
    
    /// Create a route context from a URL
    public static func from(url: URL, matchedPath: String = "", pathParameters: [String: String] = [:], extra: (any Sendable)? = nil, name: String? = nil, navigationStack: [String] = []) -> RouteContext {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        let queryParams = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        } ?? [:]
        
        return RouteContext(
            fullPath: components.path,
            matchedPath: matchedPath,
            pathParameters: pathParameters,
            queryParameters: queryParams,
            extra: extra,
            name: name,
            navigationStack: navigationStack
        )
    }
}

// MARK: - RouteContext Extensions
extension RouteContext {
    /// Get a path parameter value
    public func pathParameter(_ key: String) -> String? {
        return pathParameters[key]
    }
    
    /// Get a query parameter value
    public func queryParameter(_ key: String) -> String? {
        return queryParameters[key]
    }
    
    /// Get the extra data cast to a specific type
    public func extraAs<T>(_ type: T.Type) -> T? {
        return extra as? T
    }
}
