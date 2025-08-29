import SwiftUI
import RouteKit

/// MARK: - Phase 3: Type-Safe Routing Examples

// MARK: - Example 1: RoutableEnum Macro
@RoutableEnum
enum AppRoute: CaseIterable {
    case home
    case profile(userId: String)
    case settings
    case about
}

// MARK: - Example 2: RouteDefinition Macro
@RouteDefinition("/users/:userId")
struct UserRoute {
    let userId: String
}

@RouteDefinition("/posts/:postId/comments/:commentId")
struct PostCommentRoute {
    let postId: String
    let commentId: String
}

@RouteDefinition("/search")
struct SearchRoute {
    let query: String?
    let category: String?
}

// MARK: - Example 3: TypeSafeRoute Macro
@TypeSafeRoute
struct ProductDetailView: View {
    let routePath = "/products/:productId"
    let productId: String
    
    var body: some View {
        VStack {
            Text("Product Detail")
            Text("Product ID: \(productId)")
            
            Button("Go to Related Product") {
                // Generated type-safe navigation method
                let relatedProductId = "456"
                navigate(using: RouteKit.shared, productId: relatedProductId)
            }
        }
    }
}

// MARK: - Example 4: Comprehensive Type-Safe Router Setup
struct TypeSafeRouterExample: View {
    var body: some View {
        RouteKit(
            initialRoute: "/home"
        ) {
            // Basic routes with type safety
            Route("/") {
                ContentView()
            }
            
            // Type-safe route using UserRoute
            Route(UserRoute.self) { route in
                UserProfileView(userId: route.userId)
            }
            
            // Type-safe route using PostCommentRoute
            Route(PostCommentRoute.self) { route in
                CommentView(postId: route.postId, commentId: route.commentId)
            }
            
            // Type-safe route using SearchRoute
            Route(SearchRoute.self) { route in
                SearchResultsView(
                    query: route.query ?? "",
                    category: route.category
                )
            }
        }
    }
}

// MARK: - Supporting Views
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("RouteKit Phase 3: Type-Safe Routing")
                .font(.title)
                .padding()
            
            VStack(spacing: 12) {
                // Using RoutableEnum for type-safe navigation
                Button("Navigate to Profile") {
                    AppRoute.profile(userId: "123").navigate(with: RouteKit.shared)
                }
                
                Button("Go to Settings") {
                    AppRoute.settings.push(with: RouteKit.shared)
                }
                
                // Using type-safe route structures
                Button("View User Profile") {
                    let userRoute = UserRoute(userId: "456")
                    RouteKit.shared.navigate(to: userRoute.path)
                }
                
                Button("View Comment") {
                    let commentRoute = PostCommentRoute(postId: "789", commentId: "101")
                    RouteKit.shared.push(commentRoute.path)
                }
                
                Button("Search Products") {
                    let searchRoute = SearchRoute(query: "swift", category: "programming")
                    RouteKit.shared.navigate(to: searchRoute.path)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct UserProfileView: View {
    let userId: String
    
    var body: some View {
        VStack {
            Text("User Profile")
                .font(.title)
            Text("User ID: \(userId)")
                .font(.headline)
            
            Button("Back to Home") {
                AppRoute.home.navigate(with: RouteKit.shared)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct CommentView: View {
    let postId: String
    let commentId: String
    
    var body: some View {
        VStack {
            Text("Comment View")
                .font(.title)
            Text("Post ID: \(postId)")
            Text("Comment ID: \(commentId)")
            
            Button("Navigate to User") {
                let userRoute = UserRoute(userId: "user_\(postId)")
                RouteKit.shared.navigate(to: userRoute.path)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct SearchResultsView: View {
    let query: String
    let category: String?
    
    var body: some View {
        VStack {
            Text("Search Results")
                .font(.title)
            Text("Query: \(query)")
            if let category = category {
                Text("Category: \(category)")
            }
            
            Button("New Search") {
                let newSearch = SearchRoute(query: "routekit", category: "ios")
                RouteKit.shared.navigate(to: newSearch.path)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Advanced Type-Safe Features
extension RouteKit {
    /// Type-safe navigation using route structures
    func navigate<T: TypeSafeRoute>(to route: T) {
        navigate(to: route.path)
    }
    
    /// Type-safe push using route structures
    func push<T: TypeSafeRoute>(_ route: T) {
        push(route.path)
    }
    
    /// Type-safe route building with validation
    func buildRoute<T: TypeSafeRoute>(from type: T.Type, parameters: [String: String]) -> T? {
        return T.init(from: parameters)
    }
}

// MARK: - Type-Safe Route Builder Pattern
@resultBuilder
struct TypeSafeRouteBuilder {
    static func buildBlock(_ routes: TypeSafeRouteDefinition...) -> [TypeSafeRouteDefinition] {
        return routes
    }
}

struct TypeSafeRouteDefinition {
    let path: String
    let viewBuilder: () -> AnyView
    
    init<T: TypeSafeRoute, V: View>(
        _ routeType: T.Type,
        @ViewBuilder content: @escaping (T) -> V
    ) {
        self.path = T.pathTemplate
        self.viewBuilder = {
            // This would normally extract parameters and create the route instance
            // For this example, we'll create a placeholder
            AnyView(EmptyView())
        }
    }
}

// MARK: - Usage Examples and Documentation

/*
 
 ## Phase 3: Type-Safe Routing Features
 
 ### 1. RoutableEnum Macro
 - Automatically generates path properties for enum cases
 - Provides type-safe navigation methods
 - Supports associated values for dynamic routes
 
 ### 2. RouteDefinition Macro
 - Creates route structures from path templates
 - Validates path parameters at compile time
 - Generates initialization methods
 
 ### 3. TypeSafeRoute Macro
 - Adds navigation helpers to views
 - Provides type-safe routing integration
 - Enables compile-time route validation
 
 ### 4. Type-Safe Navigation
 ```swift
 // Enum-based routing
 AppRoute.profile(userId: "123").navigate(with: router)
 
 // Structure-based routing
 let route = UserRoute(userId: "456")
 router.navigate(to: route)
 
 // Compile-time validated paths
 @RouteDefinition("/users/:userId/posts/:postId")
 struct UserPostRoute {
     let userId: String
     let postId: String
 }
 ```
 
 ### 5. Parameter Extraction
 - Automatic parameter parsing from URLs
 - Type-safe parameter access
 - Optional parameter support
 
 ### 6. Compile-Time Validation
 - Route path validation at compile time
 - Parameter type checking
 - Missing parameter detection
 
 */
