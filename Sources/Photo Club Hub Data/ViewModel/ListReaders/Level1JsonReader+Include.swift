//
//  Level1JsonReader+Include.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 06/01/2026.
//

import CoreData   // for NSManagedObjectContext, NSPersistentContainer
import SwiftyJSON // for JSON struct

extension Level1JsonReader {

    /// Extracts and validates the file names listed in the `level1URLIncludes` array in the Header
    /// of a level1.json file. Pure parsing — no loading happens here. The split between extraction
    /// and loading exists because this runs inside the parent's synchronous `perform` block, where
    /// the concurrent include fan-out cannot be awaited (issue #760); `loadIncludes` does that part.
    ///
    /// Validation lives in `Level1Source.init(urlString:)`, which throws a `Level1URLError` naming the
    /// validation rule that was broken. In Debug an unusable entry emits a debug fatal error; in Release it is
    /// silently skipped, and the remaining entries still load.
    ///
    /// - Parameter jsonRoot: The parsed SwiftyJSON root object that holds the content of a Level 1 JSON file.
    /// - Returns: The files to include, each carrying the URL to fetch and the file name it derives
    ///   from that URL (e.g. "clubsNL" alongside its full URL).
    @Sendable static func extractIncludes(from jsonRoot: JSON) -> [Level1Source] {
        let includeJSONs: [JSON] = jsonRoot["level1Header"]["level1URLIncludes"].arrayValue
        var includes: [Level1Source] = []

        for includeJSON in includeJSONs {
            do {
                includes.append(try Level1Source(urlString: includeJSON.stringValue))
            } catch {
                // Unchanged reaction: complain loudly in Debug, skip the entry in Release. What is new is
                // that the thrown case says which rule the entry broke, so the message no longer has to be
                // written out per guard.
                ifDebugFatalError("Unusable level1URLInclude: \(error)")
                continue
            }
        }
        return includes
    }

    // swiftlint:disable function_parameter_count
    /// Concurrently loads the given `Include`d files, each on its own new background context of
    /// `usedContainer`, and suspends until ALL of them — recursively including their own Includes —
    /// have finished. This __task group__ is the structured replacement for the old fire-and-forget
    /// recursion (issue #760): it keeps the includes loading concurrently AND gives `load(...)` a
    /// join point, so "a file's load isn't done until all its spawned child Includes are done".
    static func loadIncludes(_ includes: [Level1Source],
                             isBeingTested: Bool,
                             useOnlyInBundleFile: Bool,
                             includeFilePath: [String], // used to detect loops for error checking
                             /// Tests can inject a private in-memory store for isolation,
                             /// particularly to ensure all included files use the same Core Data store/database.
                             usedContainer: NSPersistentContainer,
                             history: Level1History,
                             allowBundleFallback: Bool = true) async {
        guard includes.isEmpty == false else { return }

        // NSPersistentContainer is Sendable (unlike NSManagedObjectContext), so the @Sendable
        // child-task closures may capture it directly; creating background contexts is thread-safe.
        // "A [task] group always waits for all of its child tasks to complete before it returns."
        await withDiscardingTaskGroup { group in // discarding: child tasks return no results
            for include in includes {
                group.addTask {
                    print("Will load included file \(include.fileName).level1.json on a new background task")

                    let bgContext = LevelLoader.makeBgContext(ctxName: "Level 1 loader for \(include.fileName)",
                                                              usedContainer: usedContainer)

                    await Level1JsonReader.load( // recursively traverse Include tree
                        bgContext: bgContext,
                        fileName: include.fileName,
                        isBeingTested: isBeingTested,
                        useOnlyInBundleFile: useOnlyInBundleFile,
                        includeFilePath: includeFilePath,
                        usedContainer: usedContainer, // propagate so whole Include tree shares one CoreData container
                        history: history, // and one visited-file guard, so the tree is one pass
                        explicitRemoteURL: include.url, // fetch where the file says it lives
                        allowBundleFallback: allowBundleFallback) // inherited: an external tree has no in-app copy
                }
            }
        }
    }
    // swiftlint:enable function_parameter_count

}

/// Why a string cannot be used as a Level 1 file reference.
///
/// Distinct cases rather than a `Bool`, because the reason is shown to a user: Photo-Club-Hub#829 reports
/// a rejected Settings URL through the app's own `EmptyListReason`, where "that will not work" is a worse
/// message than naming the rule the URL broke.
enum Level1URLError: Error, Sendable {
    case notAValidURL(String)
    case notHTTPS(URL)
    case notALevel1FileName(URL)
}

/// A validated reference to one Level 1 file: where it lives, and the file name that follows from it.
///
/// Covers both kinds of reference — an entry of a `level1URLIncludes` array, and the custom root a user
/// names in Settings (Photo-Club-Hub#829) — which is why it is not called `Level1Include`. A run has one
/// root and any number of includes, so the include case is the common one but not the only one.
///
/// Both fields are needed because they answer different questions. The URL is fetched, which is what lets
/// an Include tree live outside this project. The file name resolves the embedded copy used when the
/// network is unavailable, and identifies the file in the visited-file guard and in log messages.
///
/// `fileName` is derived rather than supplied, so the two cannot disagree. It is stored rather than
/// computed because every reference is read three times — the log line, the background context's name,
/// and the recursive `load` call — while the URL it comes from never changes.
///
/// `fileName` names a *group* of organizations here — "clubsNL", "museums" — unlike the Level 2 file name,
/// which `FileSelector` derives from a single organization's `nickName`.
///
/// Deliberately `internal`. The app half of Photo-Club-Hub#829 will want it for validating the Settings
/// field, and that is the moment to widen it — public API with no user outside the package is what
/// Data#19, Data#26 and Data#28 spent three releases removing.
struct Level1Source: Sendable {
    let url: URL
    let fileName: String

    /// Parses and validates `urlString`, then derives the file name from it.
    ///
    /// - Throws: `Level1URLError.notAValidURL` if the string is not a URL at all,
    ///   `.notHTTPS` if it uses any other scheme, or `.notALevel1FileName` if the last path component is
    ///   not a valid Level 1 file name (see `fileName(inLastPathComponent:)`).
    init(urlString: String) throws {
        guard let url = URL(string: urlString) else { throw Level1URLError.notAValidURL(urlString) }
        guard url.scheme?.lowercased() == "https" else { throw Level1URLError.notHTTPS(url) }
        guard let fileName = Self.fileName(inLastPathComponent: url.lastPathComponent) else {
            throw Level1URLError.notALevel1FileName(url)
        }

        self.url = url
        self.fileName = fileName // one derivation, shared with the custom-root path
    }

    /// The file name of a level1.json URL: "clubsNL" from ".../clubsNL.level1.json", or "afd16.NL.clubs"
    /// from ".../afd16.NL.clubs.level1.json".
    ///
    /// Also used for the custom Level 1 root, which reaches `LevelLoader` as a bare URL the app has
    /// already validated. The fallback therefore covers only a URL that is not a Level 1 file name at all,
    /// such as ".../my.photo.clubs.json", which neither caller can currently produce (Photo-Club-Hub#829).
    static func fileName(of url: URL) -> String {
        fileName(inLastPathComponent: url.lastPathComponent) ?? "customLevel1Root"
    }

    /// The text before `.level1.json` (in any letter case), or nil if `lastPathComponent` is not a valid
    /// Level 1 file name.
    ///
    /// The text may contain dots, because a file is named after its folder path (`afd16.NL.clubs`, Data#106).
    /// A dot can only sit *between* two characters of the name: no leading, trailing or doubled dot.
    /// So the name is split with `omittingEmptySubsequences: false`, as split would otherwise drop
    /// exactly the empty parts that this check is looking for.
    private static func fileName(inLastPathComponent lastPathComponent: String) -> String? {
        let suffix = ".level1.json"
        guard lastPathComponent.lowercased().hasSuffix(suffix) else { return nil }

        let name = String(lastPathComponent.dropLast(suffix.count))
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ $0.isEmpty == false }) else { return nil } // also rejects an empty name

        return name
    }
}
