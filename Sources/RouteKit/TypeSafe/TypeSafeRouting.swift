import Foundation
import SwiftUI

/// Protocol for type-safe routes
public protocol TypeSafeRoute {
    /// The path pattern for this route
    var path: String { get }
    
    /// Build a Route instance from this type-safe route
    func buildRoute<Content: View>(
        @ViewBuilder builder: @escaping (RouteContext) -> Content
    ) -> Route
}

/// Default implementation for TypeSafeRoute
public extension TypeSafeRoute {
    func buildRoute<Content: View>(
        @ViewBuilder builder: @escaping (RouteContext) -> Content
    ) -> Route {
        return Route(path: path, builder: builder)
    }
}

/// Macro for generating type-safe routing from enum definitions
///
/// This macro transforms an enum into a type-safe routing system:
/// 
/// ```swift
/// @RoutableEnum
/// enum AppRoute {
///     case home
///     case profile(userId: String)
///     case products(category: String, page: Int = 1)
/// }
/// ```
///
/// The macro generates:
/// - A `path` computed property that returns the URL path
/// - Navigation methods (`navigate(using:)` and `push(using:)`)
/// - A route builder method for integration with RouteKit
@attached(member, names: named(path), named(navigate), named(push), named(buildRoute))
public macro RoutableEnum() = #externalMacro(module: "RouteKitMacros", type: "RoutableEnumMacro")

/// Macro for generating route definitions with compile-time validation
///
/// This macro validates that struct properties match path parameters:
///
/// ```swift
/// @RouteDefinition("/users/:userId/posts/:postId")
/// struct UserPostRoute {
///     let userId: String
///     let postId: String
/// }
/// ```
///
/// The macro generates:
/// - Path interpolation with parameter substitution
/// - Validated initializer ensuring all parameters are provided
/// - TypeSafeRoute conformance
@attached(member, names: named(path), named(init), named(buildRoute))
@attached(extension, conformances: TypeSafeRoute)
public macro RouteDefinition(_ path: String) = #externalMacro(module: "RouteKitMacros", type: "RouteDefinitionMacro")

/// Macro for generating type-safe route helpers
///
/// This macro adds navigation helper methods to types with a `routePath` property:
///
/// ```swift
/// @TypeSafeRoute
/// extension HomeView {
///     static let routePath = "/home"
/// }
/// ```
///
/// The macro generates:
/// - `navigate(using:)` method for type-safe navigation
/// - `push(using:)` method for type-safe route pushing
@attached(member, names: named(navigate), named(push))
public macro TypeSafeRoute() = #externalMacro(module: "RouteKitMacros", type: "TypeSafeRouteMacro")

/// Type-safe parameter extraction from route context
public struct RouteParameters<T> {
    private let context: RouteContext
    
    public init(_ context: RouteContext) {
        self.context = context
    }
    
    /// Extract a required parameter with compile-time key validation
    public func required<V>(_ keyPath: KeyPath<T, String>, as type: V.Type = V.self) throws -> V where V: LosslessStringConvertible {
        let key = String(describing: keyPath)
        guard let value = context.pathParameters[key] else {
            throw RouteParameterError.missingParameter(key)
        }
        guard let converted = V(value) else {
            throw RouteParameterError.invalidParameterType(key, V.self)
        }
        return converted
    }
    
    /// Extract an optional parameter with compile-time key validation
    public func optional<V>(_ keyPath: KeyPath<T, String>, as type: V.Type = V.self) -> V? where V: LosslessStringConvertible {
        let key = String(describing: keyPath)
        guard let value = context.pathParameters[key] else {
            return nil
        }
        return V(value)
    }
}

/// Errors related to route parameter extraction
public enum RouteParameterError: Error, LocalizedError {
    case missingParameter(String)
    case invalidParameterType(String, Any.Type)
    
    public var errorDescription: String? {
        switch self {
        case .missingParameter(let key):
            return "Missing required route parameter: \(key)"
        case .invalidParameterType(let key, let type):
            return "Cannot convert route parameter '\(key)' to type \(type)"
        }
    }
}

/// Builder for type-safe route collections
@resultBuilder
public struct TypeSafeRouteBuilder {
    public static func buildBlock(_ routes: Route...) -> [Route] {
        return routes
    }
    
    public static func buildArray(_ routes: [Route]) -> [Route] {
        return routes.compactMap { $0 }
    }
    
    public static func buildOptional(_ route: Route?) -> [Route] {
        return route.map { [$0] } ?? []
    }
    
    public static func buildEither(first route: Route) -> [Route] {
        return [route]
    }
    
    public static func buildEither(second route: Route) -> [Route] {
        return [route]
    }
}

/// Extensions to RouteKit for type-safe routing
public extension RouteKit {
    /// Initialize RouteKit with type-safe routes
    convenience init(
        @TypeSafeRouteBuilder routes: () -> [Route],
        initialRoute: String,
        shellRoutes: [ShellRoute] = [],
        statefulShellRoutes: [StatefulShellRoute] = [],
        errorBuilder: ((Error) -> AnyView)? = nil,
        redirect: ((RouteContext) -> String?)? = nil,
        debugLogDiagnostics: Bool = false,
        redirectLimit: Int = 5
    ) {
        self.init(
            routes: routes,
            initialRoute: initialRoute,
            shellRoutes: shellRoutes,
            statefulShellRoutes: statefulShellRoutes,
            errorBuilder: errorBuilder,
            redirect: redirect,
            debugLogDiagnostics: debugLogDiagnostics,
            redirectLimit: redirectLimit
        )
    }
    
    /// Navigate using a type-safe route
    func go<T: TypeSafeRoute>(_ route: T) {
        self.go(route.path)
    }
    
    /// Push using a type-safe route
    func push<T: TypeSafeRoute>(_ route: T) {
        self.push(route.path)
    }
    
    /// Navigate with type-safe parameters
    func go<T: TypeSafeRoute>(_ route: T, extra: (any Sendable)? = nil) {
        self.go(route.path, extra: extra)
    }
    
    /// Push with type-safe parameters
    func push<T: TypeSafeRoute>(_ route: T, extra: (any Sendable)? = nil) {
        self.push(route.path, extra: extra)
    }
}
