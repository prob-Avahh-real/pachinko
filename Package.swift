// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pachinko",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Pachinko", targets: ["Pachinko"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Pachinko",
            path: "Sources/Pachinko",
            exclude: ["PachinkoApp.swift"]
        ),
        .testTarget(
            name: "PachinkoTests",
            dependencies: ["Pachinko"],
            path: "Tests/PachinkoTests"
        ),
    ]
)
