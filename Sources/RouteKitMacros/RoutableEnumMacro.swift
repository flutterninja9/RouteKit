import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Macro that generates routing functionality for enum types
public struct RoutableEnumMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Ensure this is applied to an enum
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.notAnEnum
        }
        
        let pathProperty = try generatePathProperty(for: enumDecl)
        let navigateMethod = generateNavigateMethod()
        let pushMethod = generatePushMethod()
        
        return [pathProperty, navigateMethod, pushMethod]
    }
    
    private static func generatePathProperty(for enumDecl: EnumDeclSyntax) throws -> DeclSyntax {
        // For now, create a simple computed property that returns a basic path
        // This is a simplified version that can be enhanced later
        
        return DeclSyntax("""
            public var path: String {
                switch self {
                case .home:
                    return "/home"
                default:
                    return "/\\(String(describing: self).components(separatedBy: "(").first ?? "unknown")"
                }
            }
            """)
    }
    
    private static func generateNavigateMethod() -> DeclSyntax {
        return DeclSyntax("""
            public func navigate(with router: any RouteKit.RouteType) {
                router.navigate(to: self.path)
            }
            """)
    }
    
    private static func generatePushMethod() -> DeclSyntax {
        return DeclSyntax("""
            public func push(with router: any RouteKit.RouteType) {
                router.push(self.path)
            }
            """)
    }
}

enum MacroError: Error, CustomStringConvertible {
    case notAnEnum
    
    var description: String {
        switch self {
        case .notAnEnum:
            return "@RoutableEnum can only be applied to enum declarations"
        }
    }
}
