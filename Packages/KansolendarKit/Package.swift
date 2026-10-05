// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KansolendarKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KansolendarCore",
            targets: ["KansolendarCore"]
        ),
        .library(
            name: "KansolendarStorage",
            targets: ["KansolendarStorage"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "KansolendarCore"
        ),
        .target(
            name: "KansolendarStorage",
            dependencies: ["KansolendarCore"]
        ),
        .testTarget(
            name: "KansolendarCoreTests",
            dependencies: ["KansolendarCore"]
        ),
        .testTarget(
            name: "KansolendarStorageTests",
            dependencies: ["KansolendarStorage"]
        )
    ]
)
