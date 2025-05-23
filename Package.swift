// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Photo Club Hub Data",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Photo Club Hub Data",
            targets: ["Photo Club Hub Data"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Photo Club Hub Data",
            dependencies: ["SwiftyJSON"],
            resources: [
                // copying can probably also be done with a single copy command at directory level
                .copy("JSON/root.level0.json"),
                .copy("JSON/root.level1.json"),

                .copy("JSON/fgDeGender.level2.json"),
                .copy("JSON/fgWaalre.level2.json"),
                .copy("JSON/fcBellusImago.level2.json"),

                .copy("JSON/XampleMin.level2.json"),
                .copy("JSON/XampleMax.level2.json"),

                .copy("JSONtesting/empty.level0.json"),
                .copy("JSONtesting/abstractKeyword.level0.json"),
                .copy("JSONtesting/language.level0.json"),
                .copy("JSONtesting/languages.level0.json")
            ]
        ),
        .testTarget(
            name: "Photo Club Hub DataTests",
            dependencies: ["Photo Club Hub Data"]
        )
    ]
)
