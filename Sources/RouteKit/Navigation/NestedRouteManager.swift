import Foundation
import SwiftUI

/// Enhanced route matcher for hierarchical navigation patterns
public class NestedRouteManager {
    
    /// Route hierarchy cache for efficient matching
    private var routeHierarchy: [String: RouteNode] = [:]
    
    /// Initialize with routes to build hierarchy
    public init(routes: [Route]) {
        buildRouteHierarchy(routes)
    }
    
    /// Find the best matching route for a given path
    public func findBestMatch(for path: String, in routes: [Route]) -> Route? {
        // First try exact match
        if let exactMatch = routes.first(where: { $0.path == path }) {
            return exactMatch
        }
        
        // Then try parametric matches
        return findParametricMatch(for: path, in: routes)
    }
    
    /// Find nested child routes for a parent route
    public func findChildRoutes(for parentPath: String, in routes: [Route]) -> [Route] {
        return routes.filter { route in
            self.isChildRoute(route.path, of: parentPath)
        }
    }
    
    /// Check if a route is a child of another route
    public func isChildRoute(_ childPath: String, of parentPath: String) -> Bool {
        let normalizedChild = NestedRouteManager.normalizePath(childPath)
        let normalizedParent = NestedRouteManager.normalizePath(parentPath)
        
        // Child must start with parent path followed by "/"
        guard normalizedChild.hasPrefix(normalizedParent + "/") else {
            return false
        }
        
        // Make sure it's a direct child (not grandchild)
        let remainingPath = String(normalizedChild.dropFirst(normalizedParent.count + 1))
        return !remainingPath.contains("/")
    }
    
    /// Get the parent path for a given route
    public static func getParentPath(_ path: String) -> String? {
        let normalizedPath = normalizePath(path)
        
        // Root path has no parent
        if normalizedPath == "/" {
            return nil
        }
        
        guard let lastSlashIndex = normalizedPath.lastIndex(of: "/") else {
            return nil
        }
        
        let parentPath = String(normalizedPath[..<lastSlashIndex])
        return parentPath.isEmpty ? "/" : parentPath
    }
    
    /// Build breadcrumb navigation for a path
    public static func buildBreadcrumbs(for path: String) -> [String] {
        let normalizedPath = normalizePath(path)
        var breadcrumbs: [String] = ["/"]
        
        let components = normalizedPath.split(separator: "/")
        var currentPath = ""
        
        for component in components {
            currentPath += "/\(component)"
            breadcrumbs.append(currentPath)
        }
        
        return breadcrumbs
    }
    
    /// Calculate the depth of a route path
    public static func getRouteDepth(_ path: String) -> Int {
        let normalizedPath = normalizePath(path)
        if normalizedPath == "/" {
            return 0
        }
        return normalizedPath.split(separator: "/").count
    }
    
    /// Normalize a path string
    public static func normalizePath(_ path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure path starts with "/"
        if !normalized.hasPrefix("/") {
            normalized = "/" + normalized
        }
        
        // Remove trailing slash (except for root)
        if normalized.count > 1 && normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
    
    // MARK: - Private Methods
    
    private func buildRouteHierarchy(_ routes: [Route]) {
        routeHierarchy.removeAll()
        
        for route in routes {
            let node = RouteNode(route: route)
            routeHierarchy[route.path] = node
        }
        
        // Build parent-child relationships
        for (path, node) in routeHierarchy {
            if let parentPath = NestedRouteManager.getParentPath(path),
               let parentNode = routeHierarchy[parentPath] {
                parentNode.children.append(node)
                node.parent = parentNode
            }
        }
    }
    
    private func findParametricMatch(for path: String, in routes: [Route]) -> Route? {
        let pathComponents = NestedRouteManager.normalizePath(path).split(separator: "/")
        
        for route in routes {
            let routeComponents = NestedRouteManager.normalizePath(route.path).split(separator: "/")
            
            guard pathComponents.count == routeComponents.count else {
                continue
            }
            
            var isMatch = true
            for (pathComponent, routeComponent) in zip(pathComponents, routeComponents) {
                // Parameter segments start with ":"
                if !routeComponent.hasPrefix(":") && pathComponent != routeComponent {
                    isMatch = false
                    break
                }
            }
            
            if isMatch {
                return route
            }
        }
        
        return nil
    }
}

/// Internal representation of a route in the hierarchy
private class RouteNode {
    let route: Route
    weak var parent: RouteNode?
    var children: [RouteNode] = []
    
    init(route: Route) {
        self.route = route
    }
}

/// Enhanced route context with hierarchy information
public extension RouteContext {
    
    /// Get the parent path of the current route
    var parentPath: String? {
        // Use static utility method to avoid MainActor issues
        return NestedRouteManager.getParentPath(fullPath)
    }
    
    /// Get the depth of the current route
    var depth: Int {
        return NestedRouteManager.getRouteDepth(fullPath)
    }
    
    /// Get breadcrumb navigation for the current route
    var breadcrumbs: [String] {
        return NestedRouteManager.buildBreadcrumbs(for: fullPath)
    }
}

/// SwiftUI View for displaying breadcrumb navigation
public struct BreadcrumbNavigation: View {
    let breadcrumbs: [String]
    let onNavigate: (String) -> Void
    
    public init(breadcrumbs: [String], onNavigate: @escaping (String) -> Void) {
        self.breadcrumbs = breadcrumbs
        self.onNavigate = onNavigate
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(breadcrumbs.indices, id: \.self) { index in
                    let path = breadcrumbs[index]
                    let isLast = index == breadcrumbs.count - 1
                    
                    Button(action: {
                        onNavigate(path)
                    }) {
                        Text(pathDisplayName(path))
                            .foregroundColor(isLast ? .primary : .secondary)
                            .fontWeight(isLast ? .semibold : .regular)
                    }
                    .disabled(isLast)
                    
                    if !isLast {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func pathDisplayName(_ path: String) -> String {
        if path == "/" {
            return "Home"
        }
        
        let components = path.split(separator: "/")
        return components.last?.capitalized ?? "Unknown"
    }
}
