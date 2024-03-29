// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CLICapture",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CLICapture",
            targets: ["CLICapture"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/TheAngryDarling/SwiftHelpfulProtocols.git",
                 from: "1.0.0"),
        .package(url: "https://github.com/TheAngryDarling/SwiftSynchronizeObjects.git",
                 from: "1.0.1"),
        .package(url: "https://github.com/TheAngryDarling/SwiftCodeStackTrace.git",
                 from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CLICapture",
            dependencies: ["SwiftHelpfulProtocols",
                           "SynchronizeObjects",
                           "CodeStackTrace"]),
        .testTarget(
            name: "CLICaptureTests",
            dependencies: ["CLICapture"]),
    ]
)
