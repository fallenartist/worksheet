// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "DailyWorksheet",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "DailyWorksheet", targets: ["DailyWorksheet"])
    ],
    targets: [
        .executableTarget(name: "DailyWorksheet")
    ]
)
