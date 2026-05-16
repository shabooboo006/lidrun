// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LidRun",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LidRun", targets: ["LidRun"]),
        .executable(name: "LidRunHelper", targets: ["LidRunHelper"])
    ],
    targets: [
        .target(
            name: "LidRunShared"
        ),
        .executableTarget(
            name: "LidRun",
            dependencies: ["LidRunShared"],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "LidRunHelper",
            dependencies: ["LidRunShared"]
        )
    ]
)
