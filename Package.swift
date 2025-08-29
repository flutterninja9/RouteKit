// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "RouteKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RouteKit",
            targets: ["RouteKit"]),
        .library(
            name: "RouteKitMacros",
            targets: ["RouteKitMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    ],
    targets: [
        // Macro implementation that performs the source transformations
        .macro(
            name: "RouteKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        
        // Library that exposes a macro as part of its API
        .target(
            name: "RouteKit",
            dependencies: ["RouteKitMacros"]
        ),
        
        .testTarget(
            name: "RouteKitTests",
            dependencies: [
                "RouteKit",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
