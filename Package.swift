// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "abac-authorization-web",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "ABACAuthorizationWeb", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.3.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/leonidas-o/abac-authorization.git", .exact("0.9.0-alpha.5")),
        .package(name: "DNSClient", url: "https://github.com/OpenKitten/NioDNS.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Redis", package: "redis"),
            .product(name: "ABACAuthorization", package: "abac-authorization"),
            .product(name: "Leaf", package: "leaf"),
            .product(name: "DNSClient", package: "DNSClient")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(name: "Run", dependencies: [
            .target(name: "App"),
        ]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)

