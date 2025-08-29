import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Macro that generates route definitions with compile-time validation
/// 
/// Usage:
/// ```swift
/// @RouteDefinition("/users/:userId/posts/:postId")
/// struct UserPostRoute {
///     let userId: String
///     let postId: String
/// }
/// ```
public struct RouteDefinitionMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw RouteDefinitionError.notAStruct
        }
        
        guard let pathArgument = extractPathArgument(from: node) else {
            throw RouteDefinitionError.missingPathArgument
        }
        
        let pathPattern = pathArgument.trimmed.description.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
        
        var generatedMembers: [DeclSyntax] = []
        
        // Generate path property using simplified string interpolation
        let pathProperty = DeclSyntax("""
            public var path: String {
                return "\(raw: pathPattern.replacingOccurrences(of: ":", with: "\\("))"
            }
            """)
        generatedMembers.append(pathProperty)
        
        // Generate route builder method
        let routeBuilder = DeclSyntax("""
            public func buildRoute<Content: View>(@ViewBuilder builder: @escaping (RouteContext) -> Content) -> Route {
                return Route(path: self.path, builder: builder)
            }
            """)
        generatedMembers.append(routeBuilder)
        
        return generatedMembers
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }
        
        let structName = structDecl.name.text
        
        // Generate TypeSafeRoute conformance using simplified syntax
        let conformanceExtension = try ExtensionDeclSyntax("""
            extension \(raw: structName): TypeSafeRoute {}
            """)
        
        return [conformanceExtension]
    }
    
    private static func extractPathArgument(from node: AttributeSyntax) -> ExprSyntax? {
        guard let arguments = node.arguments,
              case let .argumentList(argumentList) = arguments,
              let firstArgument = argumentList.first else {
            return nil
        }
        return firstArgument.expression
    }
}

/// Errors that can occur during RouteDefinition macro expansion
enum RouteDefinitionError: Error, CustomStringConvertible {
    case notAStruct
    case missingPathArgument
    case missingParameter(String)
    
    var description: String {
        switch self {
        case .notAStruct:
            return "@RouteDefinition can only be applied to struct declarations"
        case .missingPathArgument:
            return "@RouteDefinition requires a path argument"
        case .missingParameter(let param):
            return "Missing property '\(param)' for path parameter"
        }
    }
}
