// swift-tools-version:5.3
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
        .target(name: "DailyWorksheet")
    ]
)
