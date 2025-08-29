# RouteKit - Advanced SwiftUI Routing

RouteKit is a powerful, type-safe routing library for SwiftUI applications, inspired by Flutter's GoRouter. It provides declarative routing with support for nested routes, shell routes, and advanced navigation patterns.

## Features

### Phase 1 (Foundation) ✅
- **Basic Routing**: Declarative route definition with path-based navigation
- **Named Routes**: Support for named routes and programmatic navigation
- **Route Parameters**: Dynamic path and query parameter extraction
- **Navigation Stack**: Automatic navigation history management
- **Error Handling**: Built-in error routing and custom error builders
- **Type Safety**: Full type safety with SwiftUI integration

### Phase 2 (Advanced Routing) ✅
- **Shell Routes**: Persistent UI containers for consistent app layout
- **Stateful Shell Routes**: Multi-branch navigation with independent stacks
- **Nested Routes**: Hierarchical route organization and matching
- **Enhanced Navigation**: Advanced route resolution and breadcrumb navigation
- **Navigation Controller**: Sophisticated navigation management
- **Breadcrumb Support**: Automatic breadcrumb generation for deep navigation

### Phase 3 (Coming Soon)
- **Type-Safe Routes**: Compile-time route validation with Swift macros
- **Advanced Guards**: Route guards and middleware support
- **Deep Linking**: Enhanced deep link handling and URL scheme support

## Quick Start

### Basic Setup

```swift
import SwiftUI
import RouteKit

@main
struct MyApp: App {
    let router = RouteKit(
        routes: [
            Route(path: "/") { _ in HomeView() },
            Route(path: "/profile") { _ in ProfileView() },
            Route(path: "/products/:id") { context in
                ProductView(id: context.pathParameters["id"] ?? "")
            }
        ],
        initialRoute: "/"
    )
    
    var body: some Scene {
        WindowGroup {
            RouterView(router: router)
                .environmentObject(router)
        }
    }
}
```

### Navigation

```swift
struct HomeView: View {
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        VStack {
            Button("Go to Profile") {
                router.go("/profile")
            }
            
            Button("Push Product") {
                router.push("/products/123")
            }
        }
    }
}
```

## Shell Routes

Shell routes provide persistent UI containers that remain visible across navigation:

```swift
let shellRoute = ShellRoute(
    routes: [
        Route(path: "/home") { _ in HomeContentView() },
        Route(path: "/settings") { _ in SettingsView() }
    ]
) { context, child in
    TabView {
        child
            .tabItem { Text("Main") }
    }
}
```

## Stateful Shell Routes

For complex apps with multiple navigation stacks:

```swift
let statefulShellRoute = StatefulShellRoute(
    branches: [
        StatefulShellBranch(
            id: "home",
            routes: [
                Route(path: "/home") { _ in HomeView() },
                Route(path: "/home/details") { _ in DetailsView() }
            ],
            initialLocation: "/home"
        ),
        StatefulShellBranch(
            id: "profile",
            routes: [
                Route(path: "/profile") { _ in ProfileView() }
            ],
            initialLocation: "/profile"
        )
    ]
) { context, shell in
    TabView(selection: Binding(
        get: { shell.currentIndex },
        set: { shell.goBranch($0) }
    )) {
        ForEach(0..<shell.branches.count, id: \.self) { index in
            RouterView(router: shell.router!)
                .tabItem {
                    Text(shell.branches[index].id.capitalized)
                }
                .tag(index)
        }
    }
}
```

## Nested Routes

RouteKit automatically handles hierarchical route relationships:

```swift
let routes = [
    Route(path: "/products") { _ in ProductsView() },
    Route(path: "/products/:categoryId") { context in
        CategoryView(categoryId: context.pathParameters["categoryId"] ?? "")
    },
    Route(path: "/products/:categoryId/:productId") { context in
        ProductDetailView(
            categoryId: context.pathParameters["categoryId"] ?? "",
            productId: context.pathParameters["productId"] ?? ""
        )
    }
]
```

### Breadcrumb Navigation

```swift
struct NavigationView: View {
    @StateObject private var navigationController: NavigationController
    @EnvironmentObject var router: RouteKit
    
    var body: some View {
        VStack {
            // Automatic breadcrumb generation
            BreadcrumbNavigation(
                breadcrumbs: navigationController.getBreadcrumbs()
            ) { path in
                router.go(path)
            }
            
            // Your main content
            RouterView(router: router)
        }
    }
}
```

## Advanced Navigation

### Navigation Controller

```swift
let navigationController = NavigationController(router: router)

// Find child routes
let children = navigationController.findChildRoutes(for: "/products")

// Check route relationships
let isChild = navigationController.isChildRoute("/products/electronics", of: "/products")

// Navigate to parent
if navigationController.getParentPath() != nil {
    navigationController.navigateToParent()
}

// Get current depth
let depth = navigationController.getCurrentDepth()
```

### Route Context Extensions

```swift
struct MyView: View {
    let context: RouteContext
    
    var body: some View {
        VStack {
            Text("Current Path: \(context.fullPath)")
            Text("Depth: \(context.depth)")
            Text("Parent: \(context.parentPath ?? "None")")
            
            // Display breadcrumbs
            ForEach(context.breadcrumbs, id: \.self) { crumb in
                Text(crumb)
            }
        }
    }
}
```

## Route Parameters

### Path Parameters
```swift
Route(path: "/user/:userId/posts/:postId") { context in
    PostView(
        userId: context.pathParameters["userId"] ?? "",
        postId: context.pathParameters["postId"] ?? ""
    )
}
```

### Query Parameters
```swift
// Navigate with query parameters
router.go("/search?q=swift&category=programming")

// Access in route
Route(path: "/search") { context in
    SearchView(
        query: context.queryParameters["q"] ?? "",
        category: context.queryParameters["category"]
    )
}
```

## Error Handling

```swift
let router = RouteKit(
    routes: routes,
    initialRoute: "/",
    errorBuilder: { error in
        AnyView(ErrorView(error: error))
    }
)
```

## Architecture

RouteKit follows a clean, modular architecture:

### Core Components
- **RouteKit**: Main router class managing navigation state
- **Route**: Individual route definitions with path patterns
- **RouteContext**: Navigation context with parameters and metadata
- **RouterView**: SwiftUI view that renders matched routes

### Shell System
- **ShellRoute**: Basic persistent UI containers
- **StatefulShellRoute**: Advanced multi-branch navigation
- **StatefulNavigationShell**: Independent navigation stacks per branch

### Navigation System
- **NavigationController**: Advanced navigation management
- **NestedRouteManager**: Hierarchical route resolution
- **BreadcrumbNavigation**: Automatic breadcrumb generation

## Examples

The package includes comprehensive examples:

1. **BasicRoutingExample**: Simple route navigation
2. **TabShellExample**: Basic shell route with tabs
3. **StatefulShellExample**: Complex multi-branch navigation
4. **NestedNavigationExample**: Hierarchical route navigation

## Testing

RouteKit includes extensive test coverage:
- Core routing functionality
- Shell route behavior
- Nested route management
- Navigation controller features

Run tests with:
```bash
swift test
```

## Installation

### Swift Package Manager

Add RouteKit to your project:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RouteKit.git", from: "1.0.0")
]
```

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- SwiftUI

## License

RouteKit is available under the MIT license. See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Roadmap

### Phase 3 (Planned)
- Swift macros for compile-time route validation
- Route guards and middleware system
- Enhanced deep linking support
- Animation and transition system
- Performance optimizations

RouteKit aims to be the most powerful and flexible routing solution for SwiftUI applications, providing the tools needed for everything from simple navigation to complex, nested, multi-stack applications.
