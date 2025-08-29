import Foundation
import SwiftUI

/// A shell route that displays a UI shell around matching child routes
/// Equivalent to ShellRoute in Flutter's GoRouter
public struct ShellRoute {
    /// The shell builder function that creates the persistent UI container
    public let builder: (RouteContext, AnyView) -> AnyView
    
    /// Child routes that will be displayed within this shell
    public let routes: [Route]
    
    /// Optional navigator key for managing this shell's navigation state
    public let navigatorKey: String?
    
    /// Whether to preload the initial locations of child routes
    public let preload: Bool
    
    public init(
        navigatorKey: String? = nil,
        preload: Bool = false,
        routes: [Route] = [],
        @ViewBuilder builder: @escaping (RouteContext, AnyView) -> some View
    ) {
        self.navigatorKey = navigatorKey
        self.preload = preload
        self.routes = routes
        self.builder = { context, child in AnyView(builder(context, child)) }
    }
}

/// A stateful shell route that maintains separate navigation stacks for each branch
/// Equivalent to StatefulShellRoute in Flutter's GoRouter
public struct StatefulShellRoute {
    /// The shell builder function that creates the persistent UI with navigation shell
    public let builder: (RouteContext, StatefulNavigationShell) -> AnyView
    
    /// Navigation branches for this shell route
    public let branches: [StatefulShellBranch]
    
    /// Whether to use indexed stack for managing branches
    public let useIndexedStack: Bool
    
    public init(
        branches: [StatefulShellBranch],
        useIndexedStack: Bool = true,
        @ViewBuilder builder: @escaping (RouteContext, StatefulNavigationShell) -> some View
    ) {
        self.branches = branches
        self.useIndexedStack = useIndexedStack
        self.builder = { context, shell in AnyView(builder(context, shell)) }
    }
    
    /// Convenience initializer for indexed stack pattern
    public static func indexedStack(
        branches: [StatefulShellBranch],
        @ViewBuilder builder: @escaping (RouteContext, StatefulNavigationShell) -> some View
    ) -> StatefulShellRoute {
        return StatefulShellRoute(
            branches: branches,
            useIndexedStack: true,
            builder: builder
        )
    }
}

/// A branch within a stateful shell route representing a separate navigation stack
public struct StatefulShellBranch {
    /// Unique identifier for this branch
    public let id: String
    
    /// Navigator key for this branch
    public let navigatorKey: String?
    
    /// Routes for this branch
    public let routes: [Route]
    
    /// Initial location for this branch
    public let initialLocation: String?
    
    /// Whether to preload this branch
    public let preload: Bool
    
    public init(
        id: String = UUID().uuidString,
        navigatorKey: String? = nil,
        routes: [Route],
        initialLocation: String? = nil,
        preload: Bool = false
    ) {
        self.id = id
        self.navigatorKey = navigatorKey
        self.routes = routes
        self.initialLocation = initialLocation
        self.preload = preload
    }
}

/// Navigation shell for stateful shell routes
@MainActor
public class StatefulNavigationShell: ObservableObject {
    /// Current branch index
    @Published public private(set) var currentIndex: Int = 0
    
    /// The branches managed by this shell
    public let branches: [StatefulShellBranch]
    
    /// Navigation stacks for each branch
    @Published public private(set) var branchStacks: [[String]]
    
    /// Current paths for each branch
    @Published public private(set) var branchPaths: [String]
    
    /// The router that owns this shell
    public weak var router: RouteKit?
    
    internal init(branches: [StatefulShellBranch], router: RouteKit?) {
        self.branches = branches
        self.router = router
        
        // Initialize navigation stacks and paths for each branch
        let initialStacks = branches.map { branch in
            if let initialLocation = branch.initialLocation {
                return [initialLocation]
            } else if let firstRoute = branch.routes.first {
                return [firstRoute.path]
            } else {
                return ["/"]
            }
        }
        
        self.branchStacks = initialStacks
        self.branchPaths = initialStacks.map { $0.last ?? "/" }
    }
    
    /// Navigate to a specific branch
    public func goBranch(_ index: Int, resetStack: Bool = false) {
        guard index >= 0 && index < branches.count else { return }
        
        currentIndex = index
        
        if resetStack {
            // Reset to initial location
            let initialPath = branchStacks[index].first ?? "/"
            branchStacks[index] = [initialPath]
            branchPaths[index] = initialPath
        }
        
        // Navigate to the current path of the selected branch
        router?.go(branchPaths[index])
    }
    
    /// Navigate within the current branch
    public func go(_ path: String) {
        guard currentIndex < branchStacks.count else { return }
        
        branchStacks[currentIndex] = [path]
        branchPaths[currentIndex] = path
        router?.go(path)
    }
    
    /// Push a route within the current branch
    public func push(_ path: String) {
        guard currentIndex < branchStacks.count else { return }
        
        branchStacks[currentIndex].append(path)
        branchPaths[currentIndex] = path
        router?.push(path)
    }
    
    /// Pop a route from the current branch
    public func pop() {
        guard currentIndex < branchStacks.count,
              branchStacks[currentIndex].count > 1 else { return }
        
        branchStacks[currentIndex].removeLast()
        branchPaths[currentIndex] = branchStacks[currentIndex].last ?? "/"
        router?.pop()
    }
    
    /// Get the current branch
    public var currentBranch: StatefulShellBranch? {
        guard currentIndex < branches.count else { return nil }
        return branches[currentIndex]
    }
    
    /// Check if we can pop from the current branch
    public var canPop: Bool {
        guard currentIndex < branchStacks.count else { return false }
        return branchStacks[currentIndex].count > 1
    }
    
    // MARK: - Internal State Updates
    
    /// Update branch stack (internal use)
    internal func updateBranchStack(at index: Int, with stack: [String]) {
        guard index < branchStacks.count else { return }
        branchStacks[index] = stack
        branchPaths[index] = stack.last ?? "/"
    }
    
    /// Append to branch stack (internal use)
    internal func appendToBranchStack(at index: Int, path: String) {
        guard index < branchStacks.count else { return }
        branchStacks[index].append(path)
        branchPaths[index] = path
    }
    
    /// Remove last from branch stack (internal use)
    internal func removeLastFromBranchStack(at index: Int) {
        guard index < branchStacks.count, branchStacks[index].count > 1 else { return }
        branchStacks[index].removeLast()
        branchPaths[index] = branchStacks[index].last ?? "/"
    }
    
    /// Update current index (internal use)
    internal func updateCurrentIndex(_ index: Int) {
        guard index >= 0 && index < branches.count else { return }
        currentIndex = index
    }
}

// MARK: - Shell Route Extensions

extension ShellRoute {
    /// Get all routes including nested routes in a flat list
    internal var allRoutes: [Route] {
        var result: [Route] = []
        for route in routes {
            result.append(contentsOf: route.allRoutes)
        }
        return result
    }
    
    /// Find a route that matches the given path
    internal func findMatchingRoute(for path: String) -> Route? {
        for route in allRoutes {
            if route.matches(path: path) != nil {
                return route
            }
        }
        return nil
    }
}

extension StatefulShellRoute {
    /// Get all routes from all branches in a flat list
    internal var allRoutes: [Route] {
        var result: [Route] = []
        for branch in branches {
            for route in branch.routes {
                result.append(contentsOf: route.allRoutes)
            }
        }
        return result
    }
    
    /// Find a route that matches the given path and return the branch index
    internal func findMatchingBranch(for path: String) -> (branchIndex: Int, route: Route)? {
        for (branchIndex, branch) in branches.enumerated() {
            for route in branch.routes {
                if route.matches(path: path) != nil {
                    return (branchIndex, route)
                }
                
                // Check nested routes
                for nestedRoute in route.allRoutes {
                    if nestedRoute.matches(path: path) != nil {
                        return (branchIndex, nestedRoute)
                    }
                }
            }
        }
        return nil
    }
}
