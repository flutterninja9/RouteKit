import Foundation
import SwiftUI

/// Protocol for route middleware that can process navigation requests
public protocol RouteMiddleware: Sendable {
    /// The name/identifier for this middleware
    var name: String { get }
    
    /// Process the navigation request before the route is activated
    /// - Parameter context: The route context being navigated to
    /// - Returns: A modified context or error
    func process(context: RouteContext) async -> MiddlewareResult
    
    /// Called after the route has been activated (optional)
    func onRouteActivated(context: RouteContext) async
}

/// Default implementation for onRouteActivated
public extension RouteMiddleware {
    func onRouteActivated(context: RouteContext) async {
        // Default: do nothing
    }
}

/// Result of middleware processing
public enum MiddlewareResult: Sendable {
    /// Continue with the original context
    case proceed(RouteContext)
    
    /// Continue with a modified context
    case modified(RouteContext)
    
    /// Stop processing and redirect
    case redirect(to: String)
    
    /// Stop processing with an error
    case error(Error)
}

/// Built-in logging middleware
public struct LoggingMiddleware: RouteMiddleware {
    public let name: String
    private let logger: @Sendable (String) -> Void
    
    public init(
        name: String = "LoggingMiddleware",
        logger: @escaping @Sendable (String) -> Void = { print($0) }
    ) {
        self.name = name
        self.logger = logger
    }
    
    public func process(context: RouteContext) async -> MiddlewareResult {
        logger("🛣️ Navigating to: \(context.fullPath)")
        if !context.pathParameters.isEmpty {
            logger("📝 Path parameters: \(context.pathParameters)")
        }
        if !context.queryParameters.isEmpty {
            logger("🔍 Query parameters: \(context.queryParameters)")
        }
        return .proceed(context)
    }
    
    public func onRouteActivated(context: RouteContext) async {
        logger("✅ Route activated: \(context.fullPath)")
    }
}

/// Built-in analytics middleware
public struct AnalyticsMiddleware: RouteMiddleware {
    public let name: String
    private let trackEvent: @Sendable (String, [String: Any]) -> Void
    
    public init(
        name: String = "AnalyticsMiddleware",
        trackEvent: @escaping @Sendable (String, [String: Any]) -> Void
    ) {
        self.name = name
        self.trackEvent = trackEvent
    }
    
    public func process(context: RouteContext) async -> MiddlewareResult {
        var properties: [String: Any] = [
            "path": context.fullPath,
            "matched_path": context.matchedPath
        ]
        
        if !context.pathParameters.isEmpty {
            properties["path_parameters"] = context.pathParameters
        }
        
        if !context.queryParameters.isEmpty {
            properties["query_parameters"] = context.queryParameters
        }
        
        trackEvent("route_navigation", properties)
        return .proceed(context)
    }
}

/// Built-in context modification middleware
public struct ContextModificationMiddleware: RouteMiddleware {
    public let name: String
    private let modifier: @Sendable (RouteContext) -> RouteContext
    
    public init(
        name: String = "ContextModificationMiddleware",
        modifier: @escaping @Sendable (RouteContext) -> RouteContext
    ) {
        self.name = name
        self.modifier = modifier
    }
    
    public func process(context: RouteContext) async -> MiddlewareResult {
        let modifiedContext = modifier(context)
        return .modified(modifiedContext)
    }
}

/// Built-in performance monitoring middleware
public struct PerformanceMiddleware: RouteMiddleware {
    public let name: String
    private let onPerformanceData: @Sendable (PerformanceData) -> Void
    private var startTime: CFAbsoluteTime = 0
    
    public struct PerformanceData: Sendable {
        public let path: String
        public let navigationTime: CFTimeInterval
        public let timestamp: Date
    }
    
    public init(
        name: String = "PerformanceMiddleware",
        onPerformanceData: @escaping @Sendable (PerformanceData) -> Void = { _ in }
    ) {
        self.name = name
        self.onPerformanceData = onPerformanceData
    }
    
    public func process(context: RouteContext) async -> MiddlewareResult {
        // Store start time (in a real implementation, this would be managed better)
        // startTime = CFAbsoluteTimeGetCurrent()
        return .proceed(context)
    }
    
    public func onRouteActivated(context: RouteContext) async {
        let _ = CFAbsoluteTimeGetCurrent()
        // let navigationTime = endTime - startTime
        
        let performanceData = PerformanceData(
            path: context.fullPath,
            navigationTime: 0, // Would be calculated properly with better state management
            timestamp: Date()
        )
        
        onPerformanceData(performanceData)
    }
}

/// Built-in data loading middleware
public struct DataLoadingMiddleware: RouteMiddleware {
    public let name: String
    private let loadData: @Sendable (RouteContext) async throws -> [String: any Sendable]
    
    public init(
        name: String = "DataLoadingMiddleware",
        loadData: @escaping @Sendable (RouteContext) async throws -> [String: any Sendable]
    ) {
        self.name = name
        self.loadData = loadData
    }
    
    public func process(context: RouteContext) async -> MiddlewareResult {
        do {
            let data = try await loadData(context)
            
            // Create a new context with the loaded data
            let modifiedContext = RouteContext(
                fullPath: context.fullPath,
                matchedPath: context.matchedPath,
                pathParameters: context.pathParameters,
                queryParameters: context.queryParameters,
                extra: data, // Store loaded data in extra
                name: context.name,
                navigationStack: context.navigationStack,
                error: context.error
            )
            
            return .modified(modifiedContext)
        } catch {
            return .error(error)
        }
    }
}

/// Closure-based middleware for simple cases
public struct ClosureMiddleware: RouteMiddleware {
    public let name: String
    private let processClosure: @Sendable (RouteContext) async -> MiddlewareResult
    private let onActivatedClosure: (@Sendable (RouteContext) async -> Void)?
    
    public init(
        name: String,
        process: @escaping @Sendable (RouteContext) async -> MiddlewareResult,
        onActivated: (@Sendable (RouteContext) async -> Void)? = nil
    ) {
        self.name = name
        self.processClosure = process
        self.onActivatedClosure = onActivated
    }
    
    public func process(context: RouteContext) async -> MiddlewareResult {
        return await processClosure(context)
    }
    
    public func onRouteActivated(context: RouteContext) async {
        await onActivatedClosure?(context)
    }
}

/// Errors related to middleware
public enum MiddlewareError: Error, LocalizedError {
    case processingFailed(String)
    case dataLoadingFailed(String)
    case timeout
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .processingFailed(let message):
            return "Middleware processing failed: \(message)"
        case .dataLoadingFailed(let message):
            return "Data loading failed: \(message)"
        case .timeout:
            return "Middleware processing timed out"
        case .cancelled:
            return "Middleware processing was cancelled"
        }
    }
}
