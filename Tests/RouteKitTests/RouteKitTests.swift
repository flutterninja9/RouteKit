import XCTest
@testable import RouteKit
import SwiftUI

@MainActor
final class RouteKitTests: XCTestCase {
    
    func testBasicRouteCreation() {
        let route = Route(path: "/home") { _ in
            Text("Home")
        }
        
        XCTAssertEqual(route.path, "/home")
        XCTAssertNil(route.name)
        XCTAssertTrue(route.routes.isEmpty)
    }
    
    func testNamedRouteCreation() {
        let route = Route(path: "/profile", name: "profile") { _ in
            Text("Profile")
        }
        
        XCTAssertEqual(route.path, "/profile")
        XCTAssertEqual(route.name, "profile")
    }
    
    func testRouteContext() {
        let context = RouteContext(
            fullPath: "/users/123",
            pathParameters: ["userId": "123"],
            queryParameters: ["filter": "active"]
        )
        
        XCTAssertEqual(context.fullPath, "/users/123")
        XCTAssertEqual(context.pathParameter("userId"), "123")
        XCTAssertEqual(context.queryParameter("filter"), "active")
    }
    
    func testRouteKitInitialization() {
        let routes = [
            Route(path: "/") { _ in Text("Home") },
            Route(path: "/about") { _ in Text("About") }
        ]
        
        let router = RouteKit(routes: routes, initialRoute: "/")
        
        XCTAssertEqual(router.routes.count, 2)
        XCTAssertEqual(router.initialRoute, "/")
        XCTAssertEqual(router.currentPath, "/")
    }
    
    func testURLParsing() {
        // Test URL normalization
        XCTAssertEqual(URLParser.normalizePath("home"), "/home")
        XCTAssertEqual(URLParser.normalizePath("/home/"), "/home/")
        XCTAssertEqual(URLParser.normalizePath("//home//about//"), "/home/about/")
        
        // Test URL building
        let url = URLParser.buildURL(path: "/users", queryParameters: ["page": "1", "limit": "10"])
        XCTAssertTrue(url.contains("page=1"))
        XCTAssertTrue(url.contains("limit=10"))
    }
}

// Helper to create test routes with text views
extension Route {
    static func testRoute(path: String, name: String? = nil, text: String) -> Route {
        return Route(path: path, name: name) { _ in
            Text(text)
        }
    }
}
