import Foundation

/// Utility for parsing URLs and extracting parameters
internal struct URLParser {
    
    /// Parse a URL string into components
    static func parse(_ urlString: String) -> URLComponents? {
        // Handle relative paths
        let normalizedString = urlString.hasPrefix("/") ? urlString : "/" + urlString
        return URLComponents(string: normalizedString)
    }
    
    /// Extract path parameters from a URL using a route pattern
    static func extractPathParameters(from url: String, using pattern: String) -> [String: String] {
        let urlSegments = url.split(separator: "/").map(String.init)
        let patternSegments = pattern.split(separator: "/").map(String.init)
        
        var parameters: [String: String] = [:]
        
        for (index, patternSegment) in patternSegments.enumerated() {
            guard index < urlSegments.count else { break }
            
            if patternSegment.hasPrefix(":") {
                let paramName = String(patternSegment.dropFirst())
                parameters[paramName] = urlSegments[index]
            }
        }
        
        return parameters
    }
    
    /// Extract query parameters from URL components
    static func extractQueryParameters(from components: URLComponents) -> [String: String] {
        return components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        } ?? [:]
    }
    
    /// Build a URL string with parameters
    static func buildURL(path: String, queryParameters: [String: String] = [:]) -> String {
        guard var components = URLComponents(string: path) else { return path }
        
        if !queryParameters.isEmpty {
            components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        return components.string ?? path
    }
    
    /// Normalize a path by ensuring it starts with "/" and removing double slashes
    static func normalizePath(_ path: String) -> String {
        var normalized = path
        
        // Ensure path starts with "/"
        if !normalized.hasPrefix("/") {
            normalized = "/" + normalized
        }
        
        // Remove double slashes
        while normalized.contains("//") {
            normalized = normalized.replacingOccurrences(of: "//", with: "/")
        }
        
        // Handle root path
        if normalized.isEmpty {
            normalized = "/"
        }
        
        return normalized
    }
    
    /// Check if a path matches a pattern
    static func pathMatches(_ path: String, pattern: String) -> Bool {
        let pathSegments = path.split(separator: "/")
        let patternSegments = pattern.split(separator: "/")
        
        guard pathSegments.count == patternSegments.count else {
            return false
        }
        
        for (pathSegment, patternSegment) in zip(pathSegments, patternSegments) {
            if patternSegment.hasPrefix(":") {
                // Parameter segment - always matches
                continue
            } else if pathSegment != patternSegment {
                // Literal segment must match exactly
                return false
            }
        }
        
        return true
    }
}
