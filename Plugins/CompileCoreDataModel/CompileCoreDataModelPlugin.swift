//
//  CompileCoreDataModelPlugin.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 30/07/2026.
//

import Foundation
import PackagePlugin

// Compiles the package's .xcdatamodeld into a .momd using momc.
//
// Xcode has a built-in build rule for .xcdatamodeld, but `swift build` has none: it reports the model
// as an unhandled file, so no .momd reaches the resource bundle and Bundle.module.url(forResource:)
// returns nil. That trips the fatalError in PersistenceController and takes down the whole test run.
// This plugin closes the gap, so `swift build` and `swift test` also work in a bare clone and in CI.
//
// momc lives inside Xcode rather than in the Swift toolchain, so a macOS machine with Xcode installed
// is a requirement (as it already is for building the apps).
@main
struct CompileCoreDataModelPlugin: BuildToolPlugin {

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let momc = momcInvocation(in: context)

        return try modelBundles(in: target.directoryURL).map { model in
            let output = context.pluginWorkDirectoryURL
                .appendingPathComponent(model.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("momd")

            return .buildCommand(
                displayName: "Compiling Core Data model \(model.lastPathComponent)",
                executable: momc.executable,
                arguments: momc.leadingArguments + [
                    "--module", target.moduleName,
                    model.path,
                    output.path
                ],
                inputFiles: try inputFiles(of: model),
                outputFiles: [output]
            )
        }
    }

    // momc is normally not on PATH, since it ships in Xcode's Developer directory rather than in the
    // Swift toolchain. Prefer whatever the build system knows about, and let xcrun find it otherwise.
    private func momcInvocation(in context: PluginContext) -> (executable: URL, leadingArguments: [String]) {
        if let momc = try? context.tool(named: "momc") {
            return (momc.url, [])
        }
        return (URL(fileURLWithPath: "/usr/bin/xcrun"), ["momc"])
    }

    // Located by search rather than by hardcoded path, so moving or renaming the model does not
    // silently stop producing a .momd.
    private func modelBundles(in directory: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        var models: [URL] = []
        for case let url as URL in walker where url.pathExtension == "xcdatamodeld" {
            models.append(url)
            walker.skipDescendants() // the versioned .xcdatamodel directories inside are momc's business
        }
        return models.sorted { $0.path < $1.path }
    }

    // Every file inside the model, so that editing any version triggers a recompile. Includes the
    // hidden .xccurrentversion, which decides which version momc marks as current.
    private func inputFiles(of model: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: model,
                                                          includingPropertiesForKeys: [.isRegularFileKey]) else {
            return [model]
        }

        var files: [URL] = []
        for case let url as URL in walker
        where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

}
