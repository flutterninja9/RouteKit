import Foundation
import SwiftUI
import RouteKit

/// Example demonstrating advanced guards and middleware usage
struct GuardsMiddlewareExample: View {
    @StateObject private var router: RouteKit
    
    init() {
        // Create routes with guards and middleware
        let routes = [
            Route(
                path: "/",
                name: "home",
                guards: [
                    LoggingGuard(name: "HomeLoggingGuard")
                ],
                middleware: [
                    LoggingMiddleware(name: "HomeLogging"),
                    PerformanceMiddleware(name: "HomePerformance")
                ]
            ) { _ in
                HomeView()
            },
            
            Route(
                path: "/login",
                name: "login"
            ) { _ in
                LoginView()
            },
            
            Route(
                path: "/profile",
                name: "profile",
                guards: [
                    AuthenticationGuard(
                        isAuthenticated: { UserSession.shared.isAuthenticated },
                        redirectPath: "/login"
                    ),
                    AuthorizationGuard(
                        hasPermission: { context in
                            return UserSession.shared.hasPermission("profile.view")
                        }
                    )
                ],
                middleware: [
                    LoggingMiddleware(name: "ProfileLogging"),
                    AnalyticsMiddleware(name: "ProfileAnalytics") { event, properties in
                        print("Analytics: \(event) - \(properties)")
                    },
                    DataLoadingMiddleware(name: "ProfileDataLoader") { context in
                        // Simulate loading user profile data
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        return [
                            "user": UserData(
                                id: context.pathParameters["userId"] ?? "current",
                                name: "John Doe",
                                email: "john@example.com"
                            )
                        ]
                    }
                ]
            ) { context in
                ProfileView(userData: context.extra as? [String: Any])
            },
            
            Route(
                path: "/admin",
                name: "admin",
                guards: [
                    AuthenticationGuard(
                        isAuthenticated: { UserSession.shared.isAuthenticated },
                        redirectPath: "/login"
                    ),
                    AuthorizationGuard(
                        hasPermission: { _ in UserSession.shared.isAdmin },
                        deniedPath: "/access-denied"
                    ),
                    ConditionalGuard(
                        name: "MaintenanceGuard",
                        condition: { _ in !SystemStatus.shared.isUnderMaintenance },
                        onFalse: .redirect(to: "/maintenance")
                    )
                ],
                middleware: [
                    LoggingMiddleware(name: "AdminLogging"),
                    SecurityMiddleware(name: "AdminSecurity")
                ]
            ) { _ in
                AdminView()
            },
            
            Route(path: "/access-denied") { _ in
                AccessDeniedView()
            },
            
            Route(path: "/maintenance") { _ in
                MaintenanceView()
            }
        ]
        
        self._router = StateObject(wrappedValue: RouteKit(
            routes: routes,
            initialRoute: "/",
            debugLogDiagnostics: true
        ))
    }
    
    var body: some View {
        VStack {
            // Setup global guards and middleware on appear
            RouterView(router: router)
                .environmentObject(router)
        }
        .onAppear {
            setupGlobalGuardsAndMiddleware()
        }
    }
    
    private func setupGlobalGuardsAndMiddleware() {
        // Add global logging middleware for all routes
        router.addGlobalMiddleware(
            LoggingMiddleware(name: "GlobalLogger") { message in
                print("🌐 Global: \(message)")
            }
        )
        
        // Add global performance middleware
        router.addGlobalMiddleware(
            PerformanceMiddleware(name: "GlobalPerformance") { data in
                print("⚡ Performance: \(data.path) took \(data.navigationTime)s")
            }
        )
        
        // Add global analytics middleware
        router.addGlobalMiddleware(
            AnalyticsMiddleware(name: "GlobalAnalytics") { event, properties in
                print("📊 Analytics: \(event) - \(properties)")
            }
        )
        
        // Add guards for sensitive routes using patterns
        router.addGuard(
            ValidationGuard(name: "PathValidator") { context in
                // Validate that sensitive paths don't contain suspicious parameters
                let suspiciousPatterns = ["script", "eval", "javascript:"]
                for pattern in suspiciousPatterns {
                    if context.fullPath.contains(pattern) {
                        return .invalid(message: "Suspicious path detected")
                    }
                }
                return .valid
            },
            for: "/admin/*"
        )
        
        // Add rate limiting middleware for API routes
        router.addMiddleware(
            RateLimitingMiddleware(name: "APIRateLimit"),
            for: "/api/*"
        )
    }
}

// MARK: - Custom Guards

struct LoggingGuard: RouteGuard {
    let name: String
    
    func canActivate(context: RouteContext) async -> GuardResult {
        print("🛡️ Guard '\(name)' checking access to: \(context.fullPath)")
        return .allow
    }
}

// MARK: - Custom Middleware

struct SecurityMiddleware: RouteMiddleware {
    let name: String
    
    func process(context: RouteContext) async -> MiddlewareResult {
        print("🔒 Security check for: \(context.fullPath)")
        
        // Add security headers to context
        let securityContext = RouteContext(
            fullPath: context.fullPath,
            matchedPath: context.matchedPath,
            pathParameters: context.pathParameters,
            queryParameters: context.queryParameters,
            extra: SecurityHeaders(
                contentSecurityPolicy: "default-src 'self'",
                xFrameOptions: "DENY"
            ),
            name: context.name,
            navigationStack: context.navigationStack,
            error: context.error
        )
        
        return .modified(securityContext)
    }
    
    func onRouteActivated(context: RouteContext) async {
        print("🔒 Security middleware activated for: \(context.fullPath)")
    }
}

struct RateLimitingMiddleware: RouteMiddleware {
    let name: String
    private static var requestCounts: [String: Int] = [:]
    private static var lastReset = Date()
    
    func process(context: RouteContext) async -> MiddlewareResult {
        let now = Date()
        
        // Reset counts every minute
        if now.timeIntervalSince(Self.lastReset) > 60 {
            Self.requestCounts.removeAll()
            Self.lastReset = now
        }
        
        // Check rate limit (10 requests per minute per path)
        let currentCount = Self.requestCounts[context.fullPath, default: 0]
        if currentCount >= 10 {
            return .error(MiddlewareError.processingFailed("Rate limit exceeded"))
        }
        
        Self.requestCounts[context.fullPath] = currentCount + 1
        return .proceed(context)
    }
}

// MARK: - Supporting Types

struct SecurityHeaders: Sendable {
    let contentSecurityPolicy: String
    let xFrameOptions: String
}

struct UserData: Sendable {
    let id: String
    let name: String
    let email: String
}

class UserSession: ObservableObject {
    static let shared = UserSession()
    
    @Published var isAuthenticated = false
    @Published var isAdmin = false
    @Published var permissions: Set<String> = []
    
    func hasPermission(_ permission: String) -> Bool {
        return permissions.contains(permission)
    }
    
    func login(asAdmin: Bool = false) {
        isAuthenticated = true
        isAdmin = asAdmin
        if asAdmin {
            permissions = ["profile.view", "admin.access", "users.manage"]
        } else {
            permissions = ["profile.view"]
        }
    }
    
    func logout() {
        isAuthenticated = false
        isAdmin = false
        permissions.removeAll()
    }
}

class SystemStatus: ObservableObject {
    static let shared = SystemStatus()
    
    @Published var isUnderMaintenance = false
}

// MARK: - Views

struct HomeView: View {
    @EnvironmentObject var router: RouteKit
    @StateObject private var userSession = UserSession.shared
    @StateObject private var systemStatus = SystemStatus.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Home")
                .font(.largeTitle)
            
            if userSession.isAuthenticated {
                Text("Welcome back!")
                    .foregroundColor(.green)
            } else {
                Text("Please log in")
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 20) {
                Button("Login as User") {
                    userSession.login(asAdmin: false)
                }
                .disabled(userSession.isAuthenticated)
                
                Button("Login as Admin") {
                    userSession.login(asAdmin: true)
                }
                .disabled(userSession.isAuthenticated)
                
                Button("Logout") {
                    userSession.logout()
                }
                .disabled(!userSession.isAuthenticated)
            }
            
            VStack(spacing: 10) {
                Button("Go to Profile") {
                    router.go("/profile")
                }
                
                Button("Go to Admin") {
                    router.go("/admin")
                }
                
                Button("Go to Login") {
                    router.go("/login")
                }
            }
            
            Toggle("Maintenance Mode", isOn: $systemStatus.isUnderMaintenance)
                .padding()
        }
        .padding()
    }
}

struct LoginView: View {
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
            
            Text("This is the login page")
            
            Button("Back to Home") {
                router.go("/")
            }
        }
        .padding()
    }
}

struct ProfileView: View {
    @EnvironmentObject var router: RouteKit
    let userData: [String: Any]?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Profile")
                .font(.largeTitle)
            
            if let userData = userData,
               let user = userData["user"] as? UserData {
                VStack {
                    Text("Name: \(user.name)")
                    Text("Email: \(user.email)")
                    Text("ID: \(user.id)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("Loading profile data...")
            }
            
            Button("Back to Home") {
                router.go("/")
            }
        }
        .padding()
    }
}

struct AdminView: View {
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Admin Panel")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("This is the admin area")
            
            Button("Back to Home") {
                router.go("/")
            }
        }
        .padding()
    }
}

struct AccessDeniedView: View {
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Access Denied")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("You don't have permission to access this resource")
            
            Button("Back to Home") {
                router.go("/")
            }
        }
        .padding()
    }
}

struct MaintenanceView: View {
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Under Maintenance")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("The system is currently under maintenance")
            
            Button("Back to Home") {
                router.go("/")
            }
        }
        .padding()
    }
}
