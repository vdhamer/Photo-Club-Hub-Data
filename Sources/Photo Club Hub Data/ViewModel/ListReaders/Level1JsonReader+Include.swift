//
//  Level1JsonReader+Include.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 06/01/2026.
//

import CoreData   // for NSManagedObjectContext, NSPersistentContainer
import SwiftyJSON // for JSON struct
import os         // for OSAllocatedUnfairLock (a Mutex predecessor)

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

/// Tracks which level1.json files this load pass has already visited, so the Include tree cannot
/// load a file twice or loop forever.
///
/// One instance per load pass, created by `Level1JsonReader.load`'s default argument and propagated
/// down the Include recursion. It shouldn't be a process-global singleton cleared by
/// `Model.deleteCoreDataObjects`, which made a second pass in one process (and any two tests running
/// in parallel) trip the duplicate-file error.
final public class Level1History: Sendable {

    // A Set instead of array: we only need membership (not order).
    // Set.insert reports whether the element was already present,
    // collapsing the old contains()/append() into one operation.
    //
    // OSAllocatedUnfairLock rather than Mutex: now that an instance is threaded through a pass it
    // appears in `load(...)`'s signature, and this package supports iOS 17. Mutex requires iOS 18,
    // and a type gated to iOS 18 cannot be a parameter of un-gated public API.
    // So... consider switching back to Mutex as soon as iOS 17 is no longer supported.
    private let level1History = OSAllocatedUnfairLock<Set<String>>(initialState: [])

    init() {}

    func isVisitedBefore(fileName: String) -> Bool {
        level1History.withLock { level1History in
            !level1History.insert(fileName).inserted // false the first time, true on later calls
        }
    }

    func clear() {
        level1History.withLock { level1History in
            level1History.removeAll()
        }

    }

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
    ///   not of the form `<name>.level1.json`.
    init(urlString: String) throws {
        guard let url = URL(string: urlString) else { throw Level1URLError.notAValidURL(urlString) }
        guard url.scheme?.lowercased() == "https" else { throw Level1URLError.notHTTPS(url) }

        let segments: [Substring] = url.lastPathComponent.split(separator: ".")
        guard segments.count >= 3, // avoid index-out-of-bounds on e.g. "museums.json"
              segments[1].lowercased() == "level1",
              segments[2].lowercased() == "json" else {
            throw Level1URLError.notALevel1FileName(url)
        }

        self.url = url
        self.fileName = Self.fileName(of: url) // one derivation, shared with the custom-root path
    }

    /// The file name of a level1.json URL: "clubsNL" from ".../clubsNL.level1.json".
    ///
    /// Also used for the custom Level 1 root, which reaches `LevelLoader` as a bare URL the app has
    /// already validated. The fallback therefore covers only a URL with nothing before the first dot,
    /// which neither caller can currently produce (Photo-Club-Hub#829).
    static func fileName(of url: URL) -> String {
        guard let firstSegment = url.lastPathComponent.split(separator: ".").first else {
            return "customLevel1Root"
        }
        return String(firstSegment)
    }
}
