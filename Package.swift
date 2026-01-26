// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TooCheapFi",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TooCheapFi",
            targets: ["TooCheapFi"])
    ],
    targets: [
        .executableTarget(
            name: "TooCheapFi",
            path: "Sources")
    ]
)
