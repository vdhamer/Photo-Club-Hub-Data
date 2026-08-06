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
    /// If the app has been built in Debug mode, an entry that isn't a valid URL emits a debug fatal error.
    /// If the app has been built in Release mode, invalid URL → array element is silently ignored.
    ///
    /// - Parameter jsonRoot: The parsed SwiftyJSON root object that holds the content of a Level 1 JSON file.
    /// - Returns: The base names of the files to include (e.g. ["clubsNL", "museums"]).
    @Sendable static func extractIncludeNames(from jsonRoot: JSON) -> [String] {
        let includeJSONs: [JSON] = jsonRoot["level1Header"]["level1URLIncludes"].arrayValue
        var includeNames: [String] = []

        for includeJSON in includeJSONs {
            let includeURLoptional: URL? = URL(string: includeJSON.stringValue)
            guard let includeURL: URL = includeURLoptional else {
                ifDebugFatalError("Included level1URL <\(includeJSON.stringValue)> is not a valid URL")
                continue
            }
            let includeNameSegments: [Substring] = includeURL.lastPathComponent.split(separator: ".")
            guard includeNameSegments.isEmpty == false else {
                ifDebugFatalError("level1URLIncludes contains an empty string")
                continue
            } // if it is an empty string, just ignore
            guard includeNameSegments.count >= 3, // avoid index-out-of-bounds on e.g. "museums.json"
                  includeNameSegments[1].lowercased() == "level1",
                  includeNameSegments[2].lowercased() == "json" else {
                ifDebugFatalError("level1URLInclude does not end with level1.json")
                continue
            }
            includeNames.append(String(includeNameSegments[0])) // the guards ensure there must be an element [0]
        }
        return includeNames
    }

    // swiftlint:disable function_parameter_count
    /// Concurrently loads the given `Include`d files, each on its own new background context of
    /// `usedContainer`, and suspends until ALL of them — recursively including their own Includes —
    /// have finished. This __task group__ is the structured replacement for the old fire-and-forget
    /// recursion (issue #760): it keeps the includes loading concurrently AND gives `load(...)` a
    /// join point, so "a file's load isn't done until all its spawned child Includes are done".
    static func loadIncludes(_ includeNames: [String],
                             isBeingTested: Bool,
                             useOnlyInBundleFile: Bool,
                             includeFilePath: [String], // used to detect loops for error checking
                             /// Tests can inject a private in-memory store for isolation,
                             /// particularly to ensure all included files use the same Core Data store/database.
                             usedContainer: NSPersistentContainer,
                             history: Level1History) async {
        guard includeNames.isEmpty == false else { return }

        // NSPersistentContainer is Sendable (unlike NSManagedObjectContext), so the @Sendable
        // child-task closures may capture it directly; creating background contexts is thread-safe.
        // "A [task] group always waits for all of its child tasks to complete before it returns."
        await withDiscardingTaskGroup { group in // discarding: child tasks return no results
            for includeName in includeNames {
                group.addTask {
                    print("Will load included file \(includeName).level1.json on a new background task")

                    let bgContext = LevelLoader.makeBgContext(ctxName: "Level 1 loader for \(includeName)",
                                                              usedContainer: usedContainer)

                    await Level1JsonReader.load( // recursively traverse Include tree
                        bgContext: bgContext,
                        fileName: includeName,
                        isBeingTested: isBeingTested,
                        useOnlyInBundleFile: useOnlyInBundleFile,
                        includeFilePath: includeFilePath,
                        usedContainer: usedContainer, // propagate so whole Include tree shares one CoreData container
                        history: history) // and one visited-file guard, so the tree is one pass
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

    public init() {}

    func isVisitedBefore(fileName: String) -> Bool {
        level1History.withLock { level1History in
            !level1History.insert(fileName).inserted // false the first time, true on later calls
        }
    }

    public func clear() {
        level1History.withLock { level1History in
            level1History.removeAll()
        }

    }

}
