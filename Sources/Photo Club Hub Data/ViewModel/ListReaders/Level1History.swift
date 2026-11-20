//
//  Level1History.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 06/01/2026.
//

import os // for OSAllocatedUnfairLock (a Mutex predecessor)

/// One entry per level1.json file that this load pass has visited, holding what happened to that file.
///
/// It has two uses. As a set of file names it is the visited-file guard: the Include tree cannot load a file
/// twice or loop forever. And each entry records whether its file asked for a newer Data package than this build
/// (`minimumDataPackageVersion`, Data#107), so that once the pass is over the whole picture can be read at once.
///
/// One instance per load pass, created by `LevelLoader.loadAllLevels` (or by `Level1JsonReader.load`'s default
/// argument) and propagated down the Include recursion. It shouldn't be a process-global singleton cleared by
/// `Model.deleteCoreDataObjects`, which made a second pass in one process (and any two tests running
/// in parallel) trip the duplicate-file error.
///
/// Recording and merging are kept apart. The task that loads a file only reports on that file: it marks the file as
/// visited and, if the header asks for more than this build, records the version it asked for in the file's own
/// entry. No task looks at another file's entry. Merging happens once, when the pass is over, in
/// `newerPackageRequest`. Entries hold plain text, so the visited-file guard never deals with the public
/// `NewerPackageRequest` type: those values are built from name and version only when they are read.
///
/// An example. Take this Include tree, where leafB asks for "3.11.0" and leafD for "4.0":
///
///     root
///     ├── intermediate1
///     │   ├── leafA
///     │   └── leafB      minimumDataPackageVersion "3.11.0"
///     └── intermediate2
///         ├── leafC
///         └── leafD      minimumDataPackageVersion "4.0"
///
/// 1. `LevelLoader.loadAllLevels` creates one `Level1History` and passes it to the load of root.
/// 2. root is read, and its two Includes are loaded concurrently, each on its own child task of a task group,
///    each receiving the same `Level1History`. The intermediates do the same for their leaves, so all four leaves
///    can be fetched and read at the same time.
/// 3. Every file's task adds an entry for that file. leafB's task records "3.11.0" in leafB's entry, and leafD's
///    task records "4.0" in leafD's entry, in whichever order they happen to run. The other five entries hold no
///    version.
/// 4. The load of root returns only after every task group has waited for all of its children, so by then all
///    seven entries are complete.
/// 5. `LevelLoader.loadAllLevels` reads `newerPackageRequest`, which picks ("leafD", "4.0"): the highest version
///    any file asked for. It is the same answer on every run, and updating to 4.0 satisfies leafB as well.
/// 6. The app reads that from `LevelLoader.newerPackageRequest` after `await loadAllLevels` has returned.
final public class Level1History: Sendable {

    /// What one visited file contributed to the pass, apart from its name, which is the key it is stored under.
    private struct VisitedFile: Sendable {
        var minimumDataPackageVersion: String? // optionally found in header, and only when above this build's version
    }

    // Keyed by file name: the key is all the visited-file guard checks. The value holds the rest.
    //
    // OSAllocatedUnfairLock rather than Mutex: now that an instance is threaded through a pass it
    // appears in `load(...)`'s signature, and this package supports iOS 17. Mutex requires iOS 18,
    // and a type gated to iOS 18 cannot be a parameter of un-gated public API.
    // So... consider switching back to Mutex as soon as iOS 17 is no longer supported.
    private let visitedFiles = OSAllocatedUnfairLock<[String: VisitedFile]>(initialState: [:])

    init() {}

    /// Marks `fileName` as visited. Returns false the first time, and true on later calls for the same name.
    func isVisitedBefore(fileName: String) -> Bool {
        visitedFiles.withLock { visitedFiles in
            guard visitedFiles[fileName] == nil else { return true }
            visitedFiles[fileName] = VisitedFile()
            return false
        }
    }

    /// Records, in `fileName`'s entry, the `minimumDataPackageVersion` that file asked for, as written. Call it only
    /// for a version above this build's: every recorded version counts as a request for a newer Data package.
    func record(minimumDataPackageVersion: String, for fileName: String) {
        visitedFiles.withLock { visitedFiles in
            visitedFiles[fileName, default: VisitedFile()].minimumDataPackageVersion = minimumDataPackageVersion
        }
    }

    /// Every request recorded in this pass, sorted by file name. Read it once the pass is over.
    var newerPackageRequests: [NewerPackageRequest] {
        visitedFiles.withLock { visitedFiles in
            visitedFiles.compactMap { fileName, visitedFile in
                visitedFile.minimumDataPackageVersion.map { NewerPackageRequest(fileName: fileName,
                                                                                minimumVersion: $0) }
            }
        }
        .sorted { $0.fileName < $1.fileName }
    }

    /// The request for the highest version of all files of this pass, or nil if no file asked. When several files
    /// ask for that version, the one whose file name comes first alphabetically is named (by Swift's `<` on
    /// `String`, so case-sensitive), and the answer does not depend on loading order.
    var newerPackageRequest: NewerPackageRequest? {  // see Level1JsonReader+MinimumDataPackageVersion.swift
        NewerPackageRequest.pickHighest(of: newerPackageRequests)
    }

}
