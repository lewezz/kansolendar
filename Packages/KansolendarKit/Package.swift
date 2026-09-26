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
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite"
        ),
        .target(
            name: "KansolendarCore"
        ),
        .target(
            name: "KansolendarStorage",
            dependencies: ["KansolendarCore", "CSQLite"]
        ),
        .testTarget(
            name: "KansolendarCoreTests",
            dependencies: ["KansolendarCore"]
        ),
        .testTarget(
            name: "KansolendarStorageTests",
            dependencies: ["KansolendarStorage", "CSQLite"]
        )
    ]
)
