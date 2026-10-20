// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cantainput",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CantainputCore", path: "Sources/CantainputCore"),
        .executableTarget(
            name: "Cantainput",
            dependencies: ["CantainputCore"],
            path: "Sources/Cantainput",
            exclude: ["Info.plist"]
        ),
    ]
)
