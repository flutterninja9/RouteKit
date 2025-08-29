import XCTest
import SwiftUI
@testable import RouteKit

@MainActor
final class NestedRouteTests: XCTestCase {
    
    func testNestedRouteManagerCreation() {
        let routes = [
            Route(path: "/") { _ in Text("Home") },
            Route(path: "/products") { _ in Text("Products") },
            Route(path: "/products/electronics") { _ in Text("Electronics") },
            Route(path: "/products/electronics/phones") { _ in Text("Phones") }
        ]
        
        let manager = NestedRouteManager(routes: routes)
        XCTAssertNotNil(manager)
    }
    
    func testRouteMatching() {
        let routes = [
            Route(path: "/") { _ in Text("Home") },
            Route(path: "/products") { _ in Text("Products") },
            Route(path: "/products/:categoryId") { _ in Text("Category") },
            Route(path: "/products/:categoryId/:productId") { _ in Text("Product") }
        ]
        
        let manager = NestedRouteManager(routes: routes)
        
        // Test exact matches
        XCTAssertNotNil(manager.findBestMatch(for: "/", in: routes))
        XCTAssertNotNil(manager.findBestMatch(for: "/products", in: routes))
        
        // Test parametric matches
        XCTAssertNotNil(manager.findBestMatch(for: "/products/electronics", in: routes))
        XCTAssertNotNil(manager.findBestMatch(for: "/products/electronics/phone1", in: routes))
        
        // Test non-matches
        XCTAssertNil(manager.findBestMatch(for: "/invalid", in: routes))
    }
    
    func testChildRouteFinding() {
        let routes = [
            Route(path: "/") { _ in Text("Home") },
            Route(path: "/products") { _ in Text("Products") },
            Route(path: "/products/electronics") { _ in Text("Electronics") },
            Route(path: "/products/clothing") { _ in Text("Clothing") },
            Route(path: "/products/electronics/phones") { _ in Text("Phones") },
            Route(path: "/user") { _ in Text("User") },
            Route(path: "/user/profile") { _ in Text("Profile") }
        ]
        
        let manager = NestedRouteManager(routes: routes)
        
        // Test finding children of /products
        let productChildren = manager.findChildRoutes(for: "/products", in: routes)
        XCTAssertEqual(productChildren.count, 2)
        
        let childPaths = productChildren.map { $0.path }
        XCTAssertTrue(childPaths.contains("/products/electronics"))
        XCTAssertTrue(childPaths.contains("/products/clothing"))
        
        // Test finding children of /user
        let userChildren = manager.findChildRoutes(for: "/user", in: routes)
        XCTAssertEqual(userChildren.count, 1)
        XCTAssertEqual(userChildren[0].path, "/user/profile")
        
        // Test no children
        let phoneChildren = manager.findChildRoutes(for: "/products/electronics/phones", in: routes)
        XCTAssertEqual(phoneChildren.count, 0)
    }
    
    func testChildRouteRelationship() {
        let manager = NestedRouteManager(routes: [])
        
        // Test direct parent-child relationships
        XCTAssertTrue(manager.isChildRoute("/products/electronics", of: "/products"))
        XCTAssertTrue(manager.isChildRoute("/user/profile", of: "/user"))
        
        // Test non-relationships
        XCTAssertFalse(manager.isChildRoute("/products", of: "/user"))
        XCTAssertFalse(manager.isChildRoute("/products/electronics/phones", of: "/products")) // grandchild, not child
        
        // Test same path
        XCTAssertFalse(manager.isChildRoute("/products", of: "/products"))
    }
    
    func testStaticUtilityMethods() {
        // Test parent path extraction
        XCTAssertEqual(NestedRouteManager.getParentPath("/products/electronics"), "/products")
        XCTAssertEqual(NestedRouteManager.getParentPath("/user/profile/settings"), "/user/profile")
        XCTAssertEqual(NestedRouteManager.getParentPath("/"), nil)
        XCTAssertEqual(NestedRouteManager.getParentPath("/home"), "/")
        
        // Test breadcrumb generation
        let breadcrumbs = NestedRouteManager.buildBreadcrumbs(for: "/products/electronics/phones")
        XCTAssertEqual(breadcrumbs.count, 4)
        XCTAssertEqual(breadcrumbs[0], "/")
        XCTAssertEqual(breadcrumbs[1], "/products")
        XCTAssertEqual(breadcrumbs[2], "/products/electronics")
        XCTAssertEqual(breadcrumbs[3], "/products/electronics/phones")
        
        // Test route depth calculation
        XCTAssertEqual(NestedRouteManager.getRouteDepth("/"), 0)
        XCTAssertEqual(NestedRouteManager.getRouteDepth("/home"), 1)
        XCTAssertEqual(NestedRouteManager.getRouteDepth("/products/electronics"), 2)
        XCTAssertEqual(NestedRouteManager.getRouteDepth("/user/profile/settings"), 3)
        
        // Test path normalization
        XCTAssertEqual(NestedRouteManager.normalizePath("/products/"), "/products")
        XCTAssertEqual(NestedRouteManager.normalizePath("products"), "/products")
        XCTAssertEqual(NestedRouteManager.normalizePath("/"), "/")
        XCTAssertEqual(NestedRouteManager.normalizePath("  /products/electronics  "), "/products/electronics")
    }
    
    func testRouteContextExtensions() {
        let context = RouteContext(
            fullPath: "/products/electronics/phones",
            matchedPath: "/products/:categoryId/:productId",
            pathParameters: ["categoryId": "electronics", "productId": "phones"],
            queryParameters: [:],
            extra: nil,
            name: nil,
            navigationStack: ["/", "/products", "/products/electronics", "/products/electronics/phones"],
            error: nil
        )
        
        // Test parent path
        XCTAssertEqual(context.parentPath, "/products/electronics")
        
        // Test depth
        XCTAssertEqual(context.depth, 3)
        
        // Test breadcrumbs
        let breadcrumbs = context.breadcrumbs
        XCTAssertEqual(breadcrumbs.count, 4)
        XCTAssertEqual(breadcrumbs[0], "/")
        XCTAssertEqual(breadcrumbs[1], "/products")
        XCTAssertEqual(breadcrumbs[2], "/products/electronics")
        XCTAssertEqual(breadcrumbs[3], "/products/electronics/phones")
    }
    
    func testNavigationControllerEnhancements() {
        let router = RouteKit(
            routes: [
                Route(path: "/") { _ in Text("Home") },
                Route(path: "/products") { _ in Text("Products") },
                Route(path: "/products/:categoryId") { _ in Text("Category") },
                Route(path: "/products/:categoryId/:productId") { _ in Text("Product") }
            ],
            initialRoute: "/"
        )
        
        let navigationController = NavigationController(router: router)
        
        // Test finding child routes
        let childRoutes = navigationController.findChildRoutes(for: "/products")
        XCTAssertTrue(childRoutes.count > 0)
        
        // Test child relationship check
        XCTAssertTrue(navigationController.isChildRoute("/products/electronics", of: "/products"))
        
        // Test breadcrumbs
        router.go("/products/electronics/phone1")
        let breadcrumbs = navigationController.getBreadcrumbs()
        XCTAssertTrue(breadcrumbs.count > 1)
        
        // Test parent path
        let parentPath = navigationController.getParentPath()
        XCTAssertNotNil(parentPath)
        
        // Test depth
        let depth = navigationController.getCurrentDepth()
        XCTAssertGreaterThan(depth, 0)
    }
    
    func testBreadcrumbNavigationView() {
        let breadcrumbs = ["/", "/products", "/products/electronics"]
        var navigatedPath: String?
        
        let breadcrumbView = BreadcrumbNavigation(breadcrumbs: breadcrumbs) { path in
            navigatedPath = path
        }
        
        XCTAssertNotNil(breadcrumbView)
        // Verify the closure works by simulating navigation
        breadcrumbView.onNavigate("/products")
        XCTAssertEqual(navigatedPath, "/products")
    }
}
