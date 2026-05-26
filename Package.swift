// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BillingKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "BillingKit",
            targets: ["BillingKit"]
        )
    ],
    targets: [
        .target(
            name: "BillingKit"
        ),
        .testTarget(
            name: "BillingKitTests",
            dependencies: ["BillingKit"],
            resources: [.process("Resources")]
        )
    ]
)
