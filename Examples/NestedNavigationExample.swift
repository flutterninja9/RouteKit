import SwiftUI
import RouteKit

/// Enhanced nested navigation example demonstrating hierarchical routing
struct NestedNavigationExample: View {
    @StateObject private var router = RouteKit(
        routes: [
            // Root routes
            Route(path: "/") { context in
                HomeView()
            },
            
            // Products section with nested routes
            Route(path: "/products") { context in
                ProductsView()
            },
            Route(path: "/products/:categoryId") { context in
                CategoryView(categoryId: context.pathParameters["categoryId"] ?? "")
            },
            Route(path: "/products/:categoryId/:productId") { context in
                ProductDetailView(
                    categoryId: context.pathParameters["categoryId"] ?? "",
                    productId: context.pathParameters["productId"] ?? ""
                )
            },
            Route(path: "/products/:categoryId/:productId/reviews") { context in
                ProductReviewsView(
                    categoryId: context.pathParameters["categoryId"] ?? "",
                    productId: context.pathParameters["productId"] ?? ""
                )
            },
            
            // User section with nested routes
            Route(path: "/user") { context in
                UserView()
            },
            Route(path: "/user/profile") { context in
                UserProfileView()
            },
            Route(path: "/user/settings") { context in
                UserSettingsView()
            },
            Route(path: "/user/settings/privacy") { context in
                PrivacySettingsView()
            },
            
            // Admin section with deep nesting
            Route(path: "/admin") { context in
                AdminView()
            },
            Route(path: "/admin/users") { context in
                AdminUsersView()
            },
            Route(path: "/admin/users/:userId") { context in
                AdminUserDetailView(userId: context.pathParameters["userId"] ?? "")
            },
            Route(path: "/admin/users/:userId/permissions") { context in
                UserPermissionsView(userId: context.pathParameters["userId"] ?? "")
            }
        ],
        initialRoute: "/"
    )
    
    @StateObject private var navigationController: NavigationController
    
    init() {
        let router = RouteKit(routes: [], initialRoute: "/")
        self._router = StateObject(wrappedValue: router)
        self._navigationController = StateObject(wrappedValue: NavigationController(router: router))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Breadcrumb navigation
                BreadcrumbNavigation(
                    breadcrumbs: navigationController.getBreadcrumbs()
                ) { path in
                    router.go(path)
                }
                
                // Main content
                RouterView(router: router)
                
                Spacer()
                
                // Navigation info panel
                NavigationInfoPanel(
                    router: router,
                    navigationController: navigationController
                )
            }
        }
    }
}

/// Home view with navigation options
struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Home")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Navigate to different sections:")
                .font(.headline)
            
            VStack(spacing: 10) {
                NavigationButton(title: "Products", path: "/products")
                NavigationButton(title: "User Section", path: "/user")
                NavigationButton(title: "Admin Panel", path: "/admin")
            }
        }
        .padding()
    }
}

/// Products listing view
struct ProductsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Products")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                NavigationButton(title: "Electronics", path: "/products/electronics")
                NavigationButton(title: "Clothing", path: "/products/clothing")
                NavigationButton(title: "Books", path: "/products/books")
            }
        }
        .padding()
    }
}

/// Category view showing products in a category
struct CategoryView: View {
    let categoryId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Category: \(categoryId.capitalized)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Products in \(categoryId):")
                .font(.headline)
            
            VStack(spacing: 10) {
                NavigationButton(
                    title: "Product 1",
                    path: "/products/\(categoryId)/product1"
                )
                NavigationButton(
                    title: "Product 2", 
                    path: "/products/\(categoryId)/product2"
                )
                NavigationButton(
                    title: "Product 3",
                    path: "/products/\(categoryId)/product3"
                )
            }
        }
        .padding()
    }
}

/// Product detail view
struct ProductDetailView: View {
    let categoryId: String
    let productId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(productId.capitalized)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Category: \(categoryId.capitalized)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Product details and specifications would go here.")
                .multilineTextAlignment(.center)
                .padding()
            
            NavigationButton(
                title: "View Reviews",
                path: "/products/\(categoryId)/\(productId)/reviews"
            )
        }
        .padding()
    }
}

/// Product reviews view
struct ProductReviewsView: View {
    let categoryId: String
    let productId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reviews for \(productId.capitalized)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Customer reviews and ratings would be displayed here.")
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

/// User section views
struct UserView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("User Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                NavigationButton(title: "Profile", path: "/user/profile")
                NavigationButton(title: "Settings", path: "/user/settings")
            }
        }
        .padding()
    }
}

struct UserProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("User Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Profile information and editing options.")
                .padding()
        }
        .padding()
    }
}

struct UserSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("User Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                NavigationButton(title: "Privacy Settings", path: "/user/settings/privacy")
            }
        }
        .padding()
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Privacy Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Privacy controls and data management options.")
                .padding()
        }
        .padding()
    }
}

/// Admin section views
struct AdminView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Admin Panel")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            VStack(spacing: 10) {
                NavigationButton(title: "Manage Users", path: "/admin/users")
            }
        }
        .padding()
    }
}

struct AdminUsersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("User Management")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                NavigationButton(title: "User 123", path: "/admin/users/123")
                NavigationButton(title: "User 456", path: "/admin/users/456")
                NavigationButton(title: "User 789", path: "/admin/users/789")
            }
        }
        .padding()
    }
}

struct AdminUserDetailView: View {
    let userId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("User \(userId)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("User details and management options.")
                .padding()
            
            NavigationButton(
                title: "Manage Permissions",
                path: "/admin/users/\(userId)/permissions"
            )
        }
        .padding()
    }
}

struct UserPermissionsView: View {
    let userId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions for User \(userId)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Permission management interface.")
                .padding()
        }
        .padding()
    }
}

/// Reusable navigation button
struct NavigationButton: View {
    let title: String
    let path: String
    
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        Button(action: {
            router.push(path)
        }) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
}

/// Navigation information panel
struct NavigationInfoPanel: View {
    let router: RouteKit
    let navigationController: NavigationController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Navigation Info")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Group {
                InfoRow(label: "Current Path:", value: router.currentPath)
                InfoRow(label: "Depth:", value: "\(navigationController.getCurrentDepth())")
                
                if let parentPath = navigationController.getParentPath() {
                    InfoRow(label: "Parent Path:", value: parentPath)
                    
                    Button("Go to Parent") {
                        navigationController.navigateToParent()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                if navigationController.hasChildRoutes() {
                    Text("Has child routes")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("No child routes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
}

/// Information row helper
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Preview
struct NestedNavigationExample_Previews: PreviewProvider {
    static var previews: some View {
        NestedNavigationExample()
    }
}
