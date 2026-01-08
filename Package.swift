// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Photo Club Hub Data",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
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

                .copy("JSON/clubsNL.level1.json"),
                .copy("JSON/clubsNL03.level1.json"),
                .copy("JSON/clubsNL16.level1.json"),
                .copy("JSON/clubsXamples.level1.json"),
                .copy("JSON/museums.level1.json"),
                .copy("JSON/museumsAU.level1.json"),
                .copy("JSON/museumsDE.level1.json"),
                .copy("JSON/museumsGB.level1.json"),
                .copy("JSON/museumsJP.level1.json"),
                .copy("JSON/museumsNL.level1.json"),
                .copy("JSON/museumsUS.level1.json"),
                .copy("JSON/recursionA.level1.json"),
                .copy("JSON/recursionB.level1.json"),
                .copy("JSON/root.level1.json"),
                .copy("JSON/root_.level1.json"),

                .copy("JSON/fgDeGender.level2.json"),
                .copy("JSON/fgWaalre.level2.json"),
                .copy("JSON/fcBellusImago.level2.json"),
                .copy("JSON/fcEricamera.level2.json"),
                .copy("JSON/fcDenDungen.level2.json"),
                .copy("JSON/Persoonlijk16.level2.json"),
                .copy("JSON/fgOirschot.level2.json"),
                .copy("JSON/fkGestel.level2.json"),

                .copy("JSON/Persoonlijk03.level2.json"),

                // following are behind a switch in Photo Club Hub iOS app
                .copy("JSON/XampleMin.level2.json"),
                .copy("JSON/XampleMax.level2.json"),
                .process("PhotoClubHubData.xcstrings")
            ]
        ),
        .testTarget(
            name: "Photo Club Hub DataTests",
            dependencies: ["Photo Club Hub Data"],
            resources: [
                .copy("JSON/empty.level0.json"),
                .copy("JSON/abstractExpertise.level0.json"),
                .copy("JSON/language.level0.json"),
                .copy("JSON/languages.level0.json")
            ]
        )
    ]
)
