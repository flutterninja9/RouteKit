import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that generates type-safe route helpers
/// 
/// Usage:
/// ```swift
/// @TypeSafeRoute
/// extension MyView {
///     static let routePath = "/my-view"
/// }
/// ```
public struct TypeSafeRouteMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        var generatedMembers: [DeclSyntax] = []
        
        // Generate navigation helper methods using simplified syntax
        let navigateMethod = DeclSyntax("""
            static func navigate(using router: RouteKit) {
                router.go(routePath)
            }
            """)
        generatedMembers.append(navigateMethod)
        
        let pushMethod = DeclSyntax("""
            static func push(using router: RouteKit) {
                router.push(routePath)
            }
            """)
        generatedMembers.append(pushMethod)
        
        return generatedMembers
    }
}
