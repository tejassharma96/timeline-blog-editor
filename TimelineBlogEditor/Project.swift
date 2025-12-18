import ProjectDescription

let project = Project(
    name: "TimelineBlogEditor",
    targets: [
        .target(
            name: "TimelineBlogEditor",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.tejas.TimelineBlogEditor",
            infoPlist: .default,
            buildableFolders: [
                "TimelineBlogEditor/Sources",
                "TimelineBlogEditor/Resources",
            ],
            dependencies: [
                .external(name: "Yams")
            ]
        ),
        .target(
            name: "TimelineBlogEditorTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.tejas.TimelineBlogEditorTests",
            infoPlist: .default,
            buildableFolders: [
                "TimelineBlogEditor/Tests"
            ],
            dependencies: [.target(name: "TimelineBlogEditor")]
        ),
    ]
)
