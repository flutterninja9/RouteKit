import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Compiler plugin that provides RouteKit macros
@main
struct RouteKitPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RoutableEnumMacro.self,
        RouteDefinitionMacro.self,
        TypeSafeRouteMacro.self,
    ]
}
