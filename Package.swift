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
            exclude: [
                // Handed to momc by the CompileCoreDataModel plugin, which finds it on disk rather than
                // through the manifest. Without this exclusion Xcode ALSO applies its built-in
                // .xcdatamodeld build rule, and the two producers of Photo_Club_Hub.momd collide with
                // "error: Multiple commands produce ... Photo_Club_Hub.momd".
                "Model/Photo_Club_Hub.xcdatamodeld",

                // Core Data Model Editor state (the colours used when it renders the model as a
                // diagram). Tool-managed, kept in git, but no reason to ship it in the bundle.
                // The per-version ConfigurationColors.json/EntityColors.json files live inside the
                // .xcdatamodeld and are already covered by the exclusion above; this one sits loose
                // in Model/, so it needs its own entry.
                "Model/ConfigurationColors"
            ],
            resources: [
                // copying can probably also be done with a single copy command at directory level
                .copy("JSON/root.level0.json"),

                .copy("JSON/clubsNL.level1.json"),
                .copy("JSON/clubsNL03.level1.json"),
                .copy("JSON/clubsNL16.level1.json"),
                .copy("JSON/clubTemplates.level1.json"),
                .copy("JSON/museums.level1.json"),
                .copy("JSON/museumsAU.level1.json"),
                .copy("JSON/museumsCN.level1.json"),
                .copy("JSON/museumsDE.level1.json"),
                .copy("JSON/museumsGB.level1.json"),
                .copy("JSON/museumsJP.level1.json"),
                .copy("JSON/museumsNL.level1.json"),
                .copy("JSON/museumsUS.level1.json"),
                .copy("JSON/root.level1.json"),
                .copy("JSON/root_.level1.json"),

                .copy("JSON/fcVeghel.level2.json"),
                .copy("JSON/fgDeGender.level2.json"),
                .copy("JSON/fgWaalre.level2.json"),
                .copy("JSON/fcBellusImago.level2.json"),
                .copy("JSON/fcEricamera.level2.json"),
                .copy("JSON/fcDenDungen.level2.json"),
                .copy("JSON/Persoonlijk16.level2.json"),
                .copy("JSON/fgOirschot.level2.json"),
                .copy("JSON/fkGestel.level2.json"),
                .copy("JSON/ffcShot71.level2.json"),
                .copy("JSON/fegGemert.level2.json"),

                .copy("JSON/Persoonlijk03.level2.json"),

                // following are behind a switch in Photo Club Hub iOS app
                .copy("JSON/TemplateMin.level2.json"),
                .copy("JSON/TemplateMax.level2.json"),
                .process("PhotoClubHubData.xcstrings")
            ],
            plugins: ["CompileCoreDataModel"] // turns Model/*.xcdatamodeld into a .momd in the resource bundle
        ),
        .testTarget(
            name: "Photo Club Hub DataTests",
            dependencies: ["Photo Club Hub Data"],
            resources: [
                .copy("JSON/Level0/abstractExpertise.level0.json"),
                .copy("JSON/Level0/empty.level0.json"),
                .copy("JSON/Level0/expertiseMissingIdString.level0.json"),
                .copy("JSON/Level0/garbage.level0.json"),
                .copy("JSON/Level0/language.level0.json"),
                .copy("JSON/Level0/languages.level0.json"),
                .copy("JSON/Level0/rootTest.level0.json"),
                .copy("JSON/Level1/IncludeChild.level1.json"),
                .copy("JSON/Level1/IncludeParent.level1.json"),
                .copy("JSON/Level1/clubTemplatesTest.level1.json"),
                .copy("JSON/Level1/garbage.level1.json"),
                .copy("JSON/Level1/museumsTest.level1.json"),
                .copy("JSON/Level1/recursionA.level1.json"),
                .copy("JSON/Level1/recursionB.level1.json"),
                .copy("JSON/Level1/truncated.level1.json"),
                .copy("JSON/Level2/TemplateMax.level2.json"),
                .copy("JSON/Level2/TemplateMin.level2.json"),
                .copy("JSON/Level2/fgDeGender.level2.json"),
                .copy("JSON/Level2/fgWaalre.level2.json"),
                .copy("JSON/Level2/garbage.level2.json"),
                .copy("JSON/Level2/missingIdPlus.level2.json")
            ]
        ),
        .plugin(
            name: "CompileCoreDataModel",
            capability: .buildTool()
        )
    ]
)
