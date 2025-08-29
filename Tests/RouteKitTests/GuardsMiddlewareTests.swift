import XCTest
import SwiftUI
@testable import RouteKit

@MainActor
final class GuardsMiddlewareTests: XCTestCase {
    
    var router: RouteKit!
    var guardManager: GuardMiddlewareManager!
    
    override func setUp() async throws {
        await MainActor.run {
            guardManager = GuardMiddlewareManager()
            guardManager.debugEnabled = true
            
            router = RouteKit(
                routes: [
                    Route(path: "/") { _ in AnyView(Text("Home")) },
                    Route(path: "/login") { _ in AnyView(Text("Login")) },
                    Route(path: "/profile") { _ in AnyView(Text("Profile")) },
                    Route(path: "/admin") { _ in AnyView(Text("Admin")) }
                ],
                initialRoute: "/",
                debugLogDiagnostics: true
            )
        }
    }
    
    override func tearDown() async throws {
        router = nil
        guardManager = nil
    }
    
    // MARK: - Guard Tests
    
    func testAuthenticationGuard_AllowsAuthenticated() async throws {
        let authGuard = AuthenticationGuard(
            isAuthenticated: { true },
            redirectPath: "/login"
        )
        
        let context = RouteContext(fullPath: "/profile")
        let result = await authGuard.canActivate(context: context)
        
        switch result {
        case .allow:
            XCTAssert(true)
        default:
            XCTFail("Expected allow result")
        }
    }
    
    func testAuthenticationGuard_RedirectsUnauthenticated() async throws {
        let authGuard = AuthenticationGuard(
            isAuthenticated: { false },
            redirectPath: "/login"
        )
        
        let context = RouteContext(fullPath: "/profile")
        let result = await authGuard.canActivate(context: context)
        
        switch result {
        case .redirect(let path):
            XCTAssertEqual(path, "/login")
        default:
            XCTFail("Expected redirect result")
        }
    }
    
    func testAuthorizationGuard_AllowsAuthorized() async throws {
        let authzGuard = AuthorizationGuard(
            hasPermission: { _ in true }
        )
        
        let context = RouteContext(fullPath: "/admin")
        let result = await authzGuard.canActivate(context: context)
        
        switch result {
        case .allow:
            XCTAssert(true)
        default:
            XCTFail("Expected allow result")
        }
    }
    
    func testAuthorizationGuard_RedirectsUnauthorized() async throws {
        let authzGuard = AuthorizationGuard(
            hasPermission: { _ in false },
            deniedPath: "/access-denied"
        )
        
        let context = RouteContext(fullPath: "/admin")
        let result = await authzGuard.canActivate(context: context)
        
        switch result {
        case .redirect(let path):
            XCTAssertEqual(path, "/access-denied")
        default:
            XCTFail("Expected redirect result")
        }
    }
    
    func testValidationGuard_ValidInput() async throws {
        let validationGuard = ValidationGuard { context in
            if context.fullPath.contains("admin") {
                return .valid
            }
            return .invalid(message: "Invalid path")
        }
        
        let context = RouteContext(fullPath: "/admin")
        let result = await validationGuard.canActivate(context: context)
        
        switch result {
        case .allow:
            XCTAssert(true)
        default:
            XCTFail("Expected allow result")
        }
    }
    
    func testValidationGuard_InvalidInput() async throws {
        let validationGuard = ValidationGuard { context in
            if context.fullPath.contains("script") {
                return .invalid(message: "Suspicious path")
            }
            return .valid
        }
        
        let context = RouteContext(fullPath: "/script/hack")
        let result = await validationGuard.canActivate(context: context)
        
        switch result {
        case .error(let error):
            XCTAssertTrue(error.localizedDescription.contains("Suspicious path"))
        default:
            XCTFail("Expected error result")
        }
    }
    
    func testConditionalGuard_ConditionTrue() async throws {
        let conditionalGuard = ConditionalGuard(
            condition: { _ in true }
        )
        
        let context = RouteContext(fullPath: "/test")
        let result = await conditionalGuard.canActivate(context: context)
        
        switch result {
        case .allow:
            XCTAssert(true)
        default:
            XCTFail("Expected allow result")
        }
    }
    
    func testConditionalGuard_ConditionFalse() async throws {
        let conditionalGuard = ConditionalGuard(
            condition: { _ in false },
            onFalse: .redirect(to: "/maintenance")
        )
        
        let context = RouteContext(fullPath: "/test")
        let result = await conditionalGuard.canActivate(context: context)
        
        switch result {
        case .redirect(let path):
            XCTAssertEqual(path, "/maintenance")
        default:
            XCTFail("Expected redirect result")
        }
    }
    
    func testClosureGuard() async throws {
        let closureGuard = ClosureGuard(name: "TestGuard") { context in
            if context.fullPath == "/allowed" {
                return .allow
            }
            return .deny
        }
        
        let allowedContext = RouteContext(fullPath: "/allowed")
        let allowResult = await closureGuard.canActivate(context: allowedContext)
        
        switch allowResult {
        case .allow:
            XCTAssert(true)
        default:
            XCTFail("Expected allow result")
        }
        
        let deniedContext = RouteContext(fullPath: "/denied")
        let denyResult = await closureGuard.canActivate(context: deniedContext)
        
        switch denyResult {
        case .deny:
            XCTAssert(true)
        default:
            XCTFail("Expected deny result")
        }
    }
    
    // MARK: - Middleware Tests
    
    func testLoggingMiddleware() async throws {
        let middleware = LoggingMiddleware()
        
        let context = RouteContext(fullPath: "/test")
        let result = await middleware.process(context: context)
        
        switch result {
        case .proceed(let processedContext):
            XCTAssertEqual(processedContext.fullPath, context.fullPath)
        default:
            XCTFail("Expected proceed result")
        }
    }
    
    func testAnalyticsMiddleware() async throws {
        let middleware = AnalyticsMiddleware { event, properties in
            // Just verify the middleware is called with correct event
            XCTAssertEqual(event, "route_navigation")
        }
        
        let context = RouteContext(fullPath: "/profile")
        let result = await middleware.process(context: context)
        
        switch result {
        case .proceed(let processedContext):
            XCTAssertEqual(processedContext.fullPath, context.fullPath)
        default:
            XCTFail("Expected proceed result")
        }
    }
    
    func testContextModificationMiddleware() async throws {
        let middleware = ContextModificationMiddleware { context in
            return RouteContext(
                fullPath: context.fullPath,
                matchedPath: context.matchedPath,
                pathParameters: context.pathParameters,
                queryParameters: ["modified": "true"],
                extra: context.extra,
                name: context.name,
                navigationStack: context.navigationStack,
                error: context.error
            )
        }
        
        let context = RouteContext(fullPath: "/test")
        let result = await middleware.process(context: context)
        
        switch result {
        case .modified(let modifiedContext):
            XCTAssertEqual(modifiedContext.queryParameters["modified"], "true")
        default:
            XCTFail("Expected modified result")
        }
    }
    
    func testDataLoadingMiddleware_Success() async throws {
        let middleware = DataLoadingMiddleware { context in
            return ["loadedData": "test data for \(context.fullPath)"]
        }
        
        let context = RouteContext(fullPath: "/test")
        let result = await middleware.process(context: context)
        
        switch result {
        case .modified(let modifiedContext):
            if let extra = modifiedContext.extra as? [String: Any],
               let loadedData = extra["loadedData"] as? String {
                XCTAssertTrue(loadedData.contains("/test"))
            } else {
                XCTFail("Expected loaded data in context")
            }
        default:
            XCTFail("Expected modified result")
        }
    }
    
    func testDataLoadingMiddleware_Error() async throws {
        let middleware = DataLoadingMiddleware { context in
            throw MiddlewareError.dataLoadingFailed("Network error")
        }
        
        let context = RouteContext(fullPath: "/test")
        let result = await middleware.process(context: context)
        
        switch result {
        case .error(let error):
            XCTAssertTrue(error.localizedDescription.contains("Network error"))
        default:
            XCTFail("Expected error result")
        }
    }
    
    func testClosureMiddleware() async throws {
        let middleware = ClosureMiddleware(
            name: "TestMiddleware",
            process: { context in
                return .proceed(context)
            },
            onActivated: { context in
                // Verify the context is passed correctly
                XCTAssertEqual(context.fullPath, "/test")
            }
        )
        
        let context = RouteContext(fullPath: "/test")
        let result = await middleware.process(context: context)
        
        switch result {
        case .proceed(let processedContext):
            XCTAssertEqual(processedContext.fullPath, context.fullPath)
            
            await middleware.onRouteActivated(context: context)
        default:
            XCTFail("Expected proceed result")
        }
    }
    
    // MARK: - Guard Manager Tests
    
    func testGuardManager_GlobalGuards() async throws {
        let guard1 = AuthenticationGuard(isAuthenticated: { true })
        let guard2 = AuthorizationGuard(hasPermission: { _ in true })
        
        guardManager.addGlobalGuard(guard1)
        guardManager.addGlobalGuard(guard2)
        
        let context = RouteContext(fullPath: "/test")
        let result = await guardManager.executeGuards(for: context)
        
        switch result {
        case .allow(let allowedContext):
            XCTAssertEqual(allowedContext.fullPath, context.fullPath)
        default:
            XCTFail("Expected allow result")
        }
    }
    
    func testGuardManager_RouteSpecificGuards() async throws {
        let routeGuard = AuthenticationGuard(isAuthenticated: { false }, redirectPath: "/login")
        guardManager.addGuard(routeGuard, for: "/profile")
        
        let profileContext = RouteContext(fullPath: "/profile")
        let profileResult = await guardManager.executeGuards(for: profileContext)
        
        switch profileResult {
        case .redirect(let path):
            XCTAssertEqual(path, "/login")
        default:
            XCTFail("Expected redirect result")
        }
        
        let homeContext = RouteContext(fullPath: "/home")
        let homeResult = await guardManager.executeGuards(for: homeContext)
        
        switch homeResult {
        case .allow(let allowedContext):
            XCTAssertEqual(allowedContext.fullPath, homeContext.fullPath)
        default:
            XCTFail("Expected allow result for home")
        }
    }
    
    func testGuardManager_GlobalMiddleware() async throws {
        let middleware = LoggingMiddleware()
        guardManager.addGlobalMiddleware(middleware)
        
        let context = RouteContext(fullPath: "/test")
        let result = await guardManager.executeMiddleware(for: context)
        
        switch result {
        case .proceed(let processedContext):
            XCTAssertEqual(processedContext.fullPath, context.fullPath)
        default:
            XCTFail("Expected proceed result")
        }
    }
    
    func testGuardManager_RouteSpecificMiddleware() async throws {
        let middleware = ContextModificationMiddleware { context in
            return RouteContext(
                fullPath: context.fullPath,
                matchedPath: context.matchedPath,
                pathParameters: context.pathParameters,
                queryParameters: ["profile": "true"],
                extra: context.extra,
                name: context.name,
                navigationStack: context.navigationStack,
                error: context.error
            )
        }
        
        guardManager.addMiddleware(middleware, for: "/profile")
        
        let profileContext = RouteContext(fullPath: "/profile")
        let profileResult = await guardManager.executeMiddleware(for: profileContext)
        
        switch profileResult {
        case .proceed(let processedContext):
            XCTAssertEqual(processedContext.queryParameters["profile"], "true")
        default:
            XCTFail("Expected proceed result")
        }
        
        let homeContext = RouteContext(fullPath: "/home")
        let homeResult = await guardManager.executeMiddleware(for: homeContext)
        
        switch homeResult {
        case .proceed(let processedContext):
            XCTAssertNil(processedContext.queryParameters["profile"])
        default:
            XCTFail("Expected proceed result for home")
        }
    }
    
    func testGuardManager_PatternMatching() async throws {
        let routeGuard = AuthenticationGuard(isAuthenticated: { false }, redirectPath: "/login")
        guardManager.addGuard(routeGuard, for: "/admin/*")
        
        let adminDashboardContext = RouteContext(fullPath: "/admin/dashboard")
        let adminUsersContext = RouteContext(fullPath: "/admin/users")
        let profileContext = RouteContext(fullPath: "/profile")
        
        let adminDashboardResult = await guardManager.executeGuards(for: adminDashboardContext)
        let adminUsersResult = await guardManager.executeGuards(for: adminUsersContext)
        let profileResult = await guardManager.executeGuards(for: profileContext)
        
        // Admin routes should be redirected
        switch adminDashboardResult {
        case .redirect(let path):
            XCTAssertEqual(path, "/login")
        default:
            XCTFail("Expected redirect for admin dashboard")
        }
        
        switch adminUsersResult {
        case .redirect(let path):
            XCTAssertEqual(path, "/login")
        default:
            XCTFail("Expected redirect for admin users")
        }
        
        // Profile route should be allowed
        switch profileResult {
        case .allow(let allowedContext):
            XCTAssertEqual(allowedContext.fullPath, profileContext.fullPath)
        default:
            XCTFail("Expected allow for profile")
        }
    }
    
    // MARK: - Integration Tests
    
    func testRouteKit_WithGuards() async throws {
        let authGuard = AuthenticationGuard(
            isAuthenticated: { false },
            redirectPath: "/login"
        )
        
        router.addGuard(authGuard, for: "/profile")
        
        // Initially should be at home
        XCTAssertEqual(router.currentPath, "/")
        
        // Try to navigate to profile - should be redirected to login
        router.go("/profile")
        
        // Give some time for async guard execution
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(router.currentPath, "/login")
    }
    
    func testRouteKit_WithMiddleware() async throws {
        let loggingMiddleware = LoggingMiddleware()
        
        router.addGlobalMiddleware(loggingMiddleware)
        
        router.go("/profile")
        
        // Give some time for async middleware execution
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(router.currentPath, "/profile")
    }
    
    func testGuardMiddleware_ChainExecution() async throws {
        // Setup multiple guards and middleware
        let authGuard = AuthenticationGuard(isAuthenticated: { true })
        let authzGuard = AuthorizationGuard(hasPermission: { _ in true })
        let loggingMiddleware = LoggingMiddleware()
        let analyticsMiddleware = AnalyticsMiddleware { _, _ in }
        
        guardManager.addGlobalGuard(authGuard)
        guardManager.addGlobalGuard(authzGuard)
        guardManager.addGlobalMiddleware(loggingMiddleware)
        guardManager.addGlobalMiddleware(analyticsMiddleware)
        
        let context = RouteContext(fullPath: "/test")
        
        // Test guard execution
        let guardResult = await guardManager.executeGuards(for: context)
        switch guardResult {
        case .allow(let allowedContext):
            XCTAssertEqual(allowedContext.fullPath, context.fullPath)
        default:
            XCTFail("Expected allow result from guard chain")
        }
        
        // Test middleware execution
        let middlewareResult = await guardManager.executeMiddleware(for: context)
        switch middlewareResult {
        case .proceed(let processedContext):
            XCTAssertEqual(processedContext.fullPath, context.fullPath)
        default:
            XCTFail("Expected proceed result from middleware chain")
        }
    }
    
    func testPerformanceGuardMiddleware() async throws {
        // Add performance test for guard/middleware execution
        let routeGuard = AuthenticationGuard(isAuthenticated: { true })
        let middleware = LoggingMiddleware()
        
        guardManager.addGlobalGuard(routeGuard)
        guardManager.addGlobalMiddleware(middleware)
        
        let context = RouteContext(fullPath: "/test")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let guardResult = await guardManager.executeGuards(for: context)
        let middlewareResult = await guardManager.executeMiddleware(for: context)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Should complete in reasonable time (under 100ms)
        XCTAssertLessThan(executionTime, 0.1)
        
        switch guardResult {
        case .allow:
            XCTAssert(true)
        default:
            XCTFail("Expected allow result")
        }
        
        switch middlewareResult {
        case .proceed:
            XCTAssert(true)
        default:
            XCTFail("Expected proceed result")
        }
    }
}
