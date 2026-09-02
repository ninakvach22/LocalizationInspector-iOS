// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalizationInspector-iOS",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "LocalizationInspector",
            targets: ["LocalizationInspector"]
        )
    ],
    targets: [
        .target(
            name: "LocalizationInspector"
        ),
        .testTarget(
            name: "LocalizationInspectorTests",
            dependencies: ["LocalizationInspector"]
        )
    ]
)
