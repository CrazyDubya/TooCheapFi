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
        )
    ],
    targets: [
        .executableTarget(
            name: "TooCheapFi",
            path: "Sources"
        ),
        .testTarget(
            name: "TooCheapFiTests",
            dependencies: [],
            path: "Tests"
        )
    ]
)
