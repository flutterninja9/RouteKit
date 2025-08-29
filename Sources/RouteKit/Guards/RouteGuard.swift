import Foundation
import SwiftUI

/// Protocol for route guards that can prevent navigation to certain routes
public protocol RouteGuard: Sendable {
    /// The name/identifier for this guard
    var name: String { get }
    
    /// Check if navigation to the route should be allowed
    /// - Parameter context: The route context being navigated to
    /// - Returns: A result indicating whether to allow or deny navigation
    func canActivate(context: RouteContext) async -> GuardResult
}

/// Result of a route guard check
public enum GuardResult: Sendable {
    /// Allow navigation to proceed
    case allow
    
    /// Deny navigation
    case deny
    
    /// Deny navigation and redirect to another path
    case redirect(to: String)
    
    /// Deny navigation with an error
    case error(Error)
    
    /// Allow navigation but modify the context
    case allowWithModification(RouteContext)
}

/// Built-in authentication guard
public struct AuthenticationGuard: RouteGuard {
    public let name: String
    private let isAuthenticated: @Sendable () -> Bool
    private let redirectPath: String
    
    public init(
        name: String = "AuthenticationGuard",
        isAuthenticated: @escaping @Sendable () -> Bool,
        redirectPath: String = "/login"
    ) {
        self.name = name
        self.isAuthenticated = isAuthenticated
        self.redirectPath = redirectPath
    }
    
    public func canActivate(context: RouteContext) async -> GuardResult {
        if isAuthenticated() {
            return .allow
        } else {
            return .redirect(to: redirectPath)
        }
    }
}

/// Built-in authorization guard
public struct AuthorizationGuard: RouteGuard {
    public let name: String
    private let hasPermission: @Sendable (RouteContext) -> Bool
    private let deniedPath: String?
    
    public init(
        name: String = "AuthorizationGuard",
        hasPermission: @escaping @Sendable (RouteContext) -> Bool,
        deniedPath: String? = "/access-denied"
    ) {
        self.name = name
        self.hasPermission = hasPermission
        self.deniedPath = deniedPath
    }
    
    public func canActivate(context: RouteContext) async -> GuardResult {
        if hasPermission(context) {
            return .allow
        } else if let deniedPath = deniedPath {
            return .redirect(to: deniedPath)
        } else {
            return .deny
        }
    }
}

/// Built-in validation guard
public struct ValidationGuard: RouteGuard {
    public let name: String
    private let validate: @Sendable (RouteContext) -> ValidationResult
    
    public enum ValidationResult: Sendable {
        case valid
        case invalid(message: String)
        case invalidWithRedirect(message: String, redirectTo: String)
    }
    
    public init(
        name: String = "ValidationGuard",
        validate: @escaping @Sendable (RouteContext) -> ValidationResult
    ) {
        self.name = name
        self.validate = validate
    }
    
    public func canActivate(context: RouteContext) async -> GuardResult {
        switch validate(context) {
        case .valid:
            return .allow
        case .invalid(let message):
            return .error(GuardError.validationFailed(message))
        case .invalidWithRedirect(_, let redirectTo):
            return .redirect(to: redirectTo)
        }
    }
}

/// Built-in conditional guard
public struct ConditionalGuard: RouteGuard {
    public let name: String
    private let condition: @Sendable (RouteContext) async -> Bool
    private let onFalse: GuardResult
    
    public init(
        name: String = "ConditionalGuard",
        condition: @escaping @Sendable (RouteContext) async -> Bool,
        onFalse: GuardResult = .deny
    ) {
        self.name = name
        self.condition = condition
        self.onFalse = onFalse
    }
    
    public func canActivate(context: RouteContext) async -> GuardResult {
        let result = await condition(context)
        return result ? .allow : onFalse
    }
}

/// Closure-based guard for simple cases
public struct ClosureGuard: RouteGuard {
    public let name: String
    private let guardClosure: @Sendable (RouteContext) async -> GuardResult
    
    public init(
        name: String,
        guard: @escaping @Sendable (RouteContext) async -> GuardResult
    ) {
        self.name = name
        self.guardClosure = `guard`
    }
    
    public func canActivate(context: RouteContext) async -> GuardResult {
        return await guardClosure(context)
    }
}

/// Errors related to route guards
public enum GuardError: Error, LocalizedError {
    case validationFailed(String)
    case accessDenied(String)
    case guardFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .guardFailed(let message):
            return "Guard failed: \(message)"
        case .timeout:
            return "Guard check timed out"
        }
    }
}
