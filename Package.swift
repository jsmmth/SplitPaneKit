// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SplitPaneKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "SplitPaneKit",
            targets: ["SplitPaneKit"]),
    ],
    targets: [
        .target(
            name: "SplitPaneKit",
            dependencies: [],
            path: "Sources/SplitPaneKit"
        ),
    ]
)
