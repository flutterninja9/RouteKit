import XCTest
import SwiftUI
@testable import RouteKit

@MainActor
final class ShellRouteTests: XCTestCase {
    
    func testShellRouteCreation() {
        let childRoutes = [
            Route(path: "/home") { _ in Text("Home") },
            Route(path: "/profile") { _ in Text("Profile") }
        ]
        
        let shellRoute = ShellRoute(
            routes: childRoutes,
            builder: { _, child in
                TabView {
                    child
                        .tabItem { Text("Content") }
                }
            }
        )
        
        XCTAssertEqual(shellRoute.routes.count, 2)
        XCTAssertNotNil(shellRoute.builder)
    }
    
    func testStatefulShellRouteCreation() {
        let branches = [
            StatefulShellBranch(
                id: "home",
                routes: [
                    Route(path: "/home") { _ in Text("Home") },
                    Route(path: "/home/details") { _ in Text("Details") }
                ],
                initialLocation: "/home"
            ),
            StatefulShellBranch(
                id: "profile",
                routes: [
                    Route(path: "/profile") { _ in Text("Profile") }
                ],
                initialLocation: "/profile"
            )
        ]
        
        let statefulShellRoute = StatefulShellRoute(
            branches: branches,
            builder: { _, shell in
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
        )
        
        XCTAssertEqual(statefulShellRoute.branches.count, 2)
        XCTAssertEqual(statefulShellRoute.branches[0].id, "home")
        XCTAssertEqual(statefulShellRoute.branches[1].id, "profile")
    }
    
    func testStatefulNavigationShell() {
        let router = RouteKit()
        let branches = [
            StatefulShellBranch(
                id: "home",
                routes: [
                    Route(path: "/home") { _ in Text("Home") }
                ],
                initialLocation: "/home"
            )
        ]
        
        let shell = StatefulNavigationShell(branches: branches, router: router)
        
        XCTAssertEqual(shell.currentIndex, 0)
        XCTAssertEqual(shell.branches.count, 1)
        XCTAssertEqual(shell.branches[0].id, "home")
        XCTAssertEqual(shell.branchStacks[0].count, 1)
        XCTAssertEqual(shell.branchStacks[0][0], "/home")
    }
    
    func testStatefulShellBranchNavigation() {
        let router = RouteKit()
        let branches = [
            StatefulShellBranch(
                id: "home",
                routes: [
                    Route(path: "/home") { _ in Text("Home") },
                    Route(path: "/home/details") { _ in Text("Details") }
                ],
                initialLocation: "/home"
            ),
            StatefulShellBranch(
                id: "profile",
                routes: [
                    Route(path: "/profile") { _ in Text("Profile") }
                ],
                initialLocation: "/profile"
            )
        ]
        
        let shell = StatefulNavigationShell(branches: branches, router: router)
        
        // Test initial state
        XCTAssertEqual(shell.currentIndex, 0)
        XCTAssertEqual(shell.branchStacks[0].count, 1)
        XCTAssertEqual(shell.branchStacks[0][0], "/home")
        
        // Test navigation within branch
        shell.push("/home/details")
        XCTAssertEqual(shell.branchStacks[0].count, 2)
        XCTAssertEqual(shell.branchStacks[0][1], "/home/details")
        
        // Test branch switching
        shell.goBranch(1)
        XCTAssertEqual(shell.currentIndex, 1)
        
        // Test that other branch stack is preserved
        XCTAssertEqual(shell.branchStacks[0].count, 2) // Home branch still has 2 items
        XCTAssertEqual(shell.branchStacks[1].count, 1) // Profile branch has 1 item
    }
    
    func testRouteKitWithShellRoutes() {
        let router = RouteKit()
        
        let shellRoute = ShellRoute(
            routes: [
                Route(path: "/content") { _ in Text("Content") }
            ],
            builder: { _, child in
                TabView {
                    child
                }
            }
        )
        
        let statefulShellRoute = StatefulShellRoute(
            branches: [
                StatefulShellBranch(
                    id: "home",
                    routes: [Route(path: "/home") { _ in Text("Home") }],
                    initialLocation: "/home"
                )
            ],
            builder: { _, _ in TabView { Text("App") } }
        )
        
        // Test that shell routes can be stored
        XCTAssertEqual(router.shellRoutes.count, 0)
        XCTAssertEqual(router.statefulShellRoutes.count, 0)
        
        // Shell routes would typically be added through configuration
        // This test validates the structure exists
        XCTAssertEqual(shellRoute.routes.count, 1)
        XCTAssertEqual(statefulShellRoute.branches.count, 1)
        XCTAssertEqual(statefulShellRoute.branches[0].id, "home")
    }
}
