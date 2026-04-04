// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "moji",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TsukiApp", targets: ["TsukiApp"])
    ],
    targets: [
        .executableTarget(
            name: "TsukiApp",
            path: "TsukiApp"
        )
    ]
)
