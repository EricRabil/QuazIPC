// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuazIPC",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "QuazIPC",
            targets: ["QuazIPC"]),
        .executable(name: "Example", targets: [
            "Example"
        ]),
        .executable(name: "NSXPCBridgingExample", targets: [
            "NSXPCBridgingExample"
        ])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/daniel-grumberg/CodableXPC", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "QuazIPC",
            dependencies: ["CodableXPC"],
            linkerSettings: [LinkerSetting.linkedLibrary("bsm", .when(platforms: [.macOS]))]),
        .target(name: "Example", dependencies: ["QuazIPC"]),
        .target(name: "NSXPCBridgingExample", dependencies: ["QuazIPC"]),
        .testTarget(
            name: "QuazIPCTests",
            dependencies: ["QuazIPC"]),
    ]
)
