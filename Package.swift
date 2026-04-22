// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "Worksheet",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "Worksheet", targets: ["DailyWorksheet"])
    ],
    targets: [
        .executableTarget(name: "DailyWorksheet")
    ]
)
