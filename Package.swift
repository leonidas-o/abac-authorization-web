// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "ABACAuthorizationWeb",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/auth.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "3.0.0"),
        .package(url: "https://github.com/leonidas-o/abac-authorization.git", .exact("0.9.0-alpha.1"))
    ],
    targets: [
        .target(name: "App", dependencies: ["Leaf", "Redis", "ABACAuthorization", "Authentication", "FluentPostgreSQL", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

