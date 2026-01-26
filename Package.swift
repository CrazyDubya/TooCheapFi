// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TooCheapFi",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "TooCheapFi",
            targets: ["TooCheapFi"]
        ),
        .library(
            name: "TooCheapFiCore",
            targets: ["TooCheapFiCore"]
        )
    ],
    targets: [
        // Core library containing all app logic
        .target(
            name: "TooCheapFiCore",
            path: "Sources",
            exclude: ["main.swift"]
        ),
        // Executable that depends on core library
        .executableTarget(
            name: "TooCheapFi",
            dependencies: ["TooCheapFiCore"],
            path: "Sources",
            sources: ["main.swift"]
        ),
        // Tests that can now import the core library
        .testTarget(
            name: "TooCheapFiTests",
            dependencies: ["TooCheapFiCore"],
            path: "Tests"
        )
    ]
)
