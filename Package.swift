// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KansolendarWorkspace",
    platforms: [
        .macOS(.v14)
    ],
    products: [],
    dependencies: [.package(path: "Packages/KansolendarKit")],
    targets: [
        // A library test harness for the actual app state sources, not a second app.
        .target(
            name: "KansolendarAppState",
            dependencies: [
                .product(name: "KansolendarCore", package: "KansolendarKit"),
                .product(name: "KansolendarStorage", package: "KansolendarKit")
            ],
            path: "Kansolendar/App",
            exclude: ["AppTheme.swift", "CalendarEditors.swift", "CalendarScaleViews.swift", "CalendarWorkspaceView.swift", "KansolendarApp.swift", "MonthCalendarView.swift", "RootView.swift"],
            sources: ["VaultViewModel.swift", "VaultLifecycle.swift", "EventDateAdapter.swift", "VaultError+Presentation.swift", "VaultFilePanel.swift"]
        ),
        .testTarget(name: "KansolendarAppStateTests", dependencies: ["KansolendarAppState"], path: "Tests/KansolendarAppStateTests")
    ]
)
