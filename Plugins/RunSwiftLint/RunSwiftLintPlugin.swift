//
//  RunSwiftLintPlugin.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 06/08/2026.
//

import Foundation
import PackagePlugin

// Runs SwiftLint on every build of the package, which is what the two consuming apps get from their
// "Run SwiftLint" Xcode build phase. A package has no .xcodeproj to hang a build phase on, so the
// equivalent is a build tool plugin.
//
// Uses the swiftlint already installed with Homebrew rather than depending on a SwiftLint package.
// Two reasons: adding the dependency would make both apps resolve it as well, and the build would
// then lint with a different swiftlint version than the one on the command line. The trade-off is
// that swiftlint has to be installed — same assumption the apps' build phase makes, and handled the
// same way, with a warning rather than a build failure.
//
// A missing swiftlint is deliberately NOT an error: a bare clone, or CI without Homebrew, should
// still build and test.
@main
struct RunSwiftLintPlugin: BuildToolPlugin {

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let swiftlint = swiftlintURL(in: context) else {
            Diagnostics.warning("SwiftLint not installed, download from https://github.com/realm/SwiftLint")
            return []
        }

        // Lints the whole package rather than just `target.directoryURL`, so a build covers the same
        // files as typing `swiftlint` in the package root — Tests/ and Plugins/ included. The paths in
        // .swiftlint.yml's `excluded:` are relative to that file, so passing --config keeps them valid.
        let packageDirectory = context.package.directoryURL

        // Build commands run in a sandbox that permits writing only inside the build directory, so
        // SwiftLint's default cache under ~/Library/Caches would be denied. Keep the cache, but put it
        // somewhere allowed.
        let cache = context.pluginWorkDirectoryURL.appendingPathComponent("cache")

        // A `.buildCommand` rather than a `.prebuildCommand`, because only a build command's output is
        // shown in the build log: SwiftPM discards a prebuild command's stdout when it exits 0, which
        // for a non-strict linter is always — the violations would be found and then thrown away.
        //
        // Build commands are scheduled from their declared outputs, and a linter has none, so it writes
        // a stamp file. `;` rather than `&&`: the stamp must be written even when SwiftLint reports
        // violations, otherwise a build that found violations would re-lint identical sources forever.
        // Violations stay advisory this way, matching the apps' build phase, which also only warns.
        let stamp = context.pluginWorkDirectoryURL.appendingPathComponent("SwiftLintStamp.swift")
        let script = """
            \(shellQuoted(swiftlint.path)) lint --quiet \
            --config \(shellQuoted(packageDirectory.appendingPathComponent(".swiftlint.yml").path)) \
            --cache-path \(shellQuoted(cache.path)) \
            \(shellQuoted(packageDirectory.path)) \
            ; echo '// Written by RunSwiftLintPlugin. Intentionally empty.' > \(shellQuoted(stamp.path))
            """

        return [
            .buildCommand(
                displayName: "Running SwiftLint",
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", script],
                // Every Swift file in the package, so that editing any of them re-lints. Unlike the
                // apps' build phase (alwaysOutOfDate = 1) an unchanged rebuild is skipped, which is
                // the same result for less work.
                inputFiles: swiftFiles(in: packageDirectory),
                // A .swift stamp rather than, say, .txt: plugin outputs are fed back into the target,
                // where an unknown extension becomes an unhandled-file warning or a stray resource in
                // Bundle.module. A comment-only Swift file compiles to nothing and stays out of the way.
                outputFiles: [stamp]
            )
        ]
    }

    private func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func swiftFiles(in directory: URL) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: directory,
                                                          includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .filter { !$0.path.contains("/.build/") } // SwiftPM checkouts and build artifacts
    }

    // swiftlint ships neither with Xcode nor with the Swift toolchain, so it has to be found on disk.
    // Mirrors `CompileCoreDataModelPlugin.momcInvocation(in:)`: prefer whatever the build system knows
    // about, and fall back to the usual Homebrew locations (Apple silicon first, then Intel).
    private func swiftlintURL(in context: PluginContext) -> URL? {
        if let swiftlint = try? context.tool(named: "swiftlint") {
            return swiftlint.url
        }
        let brewPaths = ["/opt/homebrew/bin/swiftlint", "/usr/local/bin/swiftlint"]
        return brewPaths
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

}
