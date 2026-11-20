//
//  Level1JsonReader+MinimumDataPackageVersion.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 20/11/2026.
//

import SwiftyJSON // for JSON struct
import os         // for OSAllocatedUnfairLock (a Mutex predecessor)

// Everything about the optional `minimumDataPackageVersion` in a Level 1 file's header (Data#107),
// presented in the order it happens during a load pass:
// 1. `Level1JsonReader.checkMinimumDataPackageVersion` reads one Level 1 file's header and, if that file requests
//    a Data package more recent than this build, records the version it asked for in that file's entry of the
//    pass's `Level1History`.
// 2. Once the pass is done, `Level1History.newerPackageRequest` hands all recorded requests to
//    `NewerPackageRequest.pickHighest(of:)`, which picks the most picky/recent request to report.
// 3. `LevelLoader.loadAllLevels` publishes that as `LevelLoader.newerPackageRequest`, where the apps read it.
// Only the storage stays elsewhere: one field per file in `Level1History`. `DottedVersion` compares the numbers.

// MARK: NewerPackageRequest

/// The name of a Level 1 file whose header requests a newer Data package than the one this build contains, and the
/// version it asks for (Data#107).
///
/// Read from `LevelLoader.newerPackageRequest`. The file name and version are given so that an app can show
/// them in a message meant for a maintainer, and so the claim can be checked: if the value in that file is itself
/// wrong, it is that file that needs correcting rather than the software that needs updating.
public struct NewerPackageRequest: Sendable, Equatable {

    /// The file that asked, without ".level1.json": for example "root_".
    /// When several files ask for the same highest version, the one whose name comes alphabetically first is given.
    public let fileName: String

    /// The `minimumDataPackageVersion` as written in that file: for example "3.11.0".
    /// The version of this build is `PhotoClubHubDataVersion.semver`.
    public let minimumVersion: String

    /// Returns the highest version, or nil if `requests` is empty. When several requests are for that
    /// version, the one whose file name comes first alphabetically is returned (by Swift's `<` on `String`, so
    /// case-sensitive). The order of `requests` does not matter, so neither does the order in which files loaded.
    static func pickHighest(of requests: [NewerPackageRequest]) -> NewerPackageRequest? {
        // Every recorded version parses: `checkMinimumDataPackageVersion` records only one that did.
        let ranked = requests.compactMap { request in
            DottedVersion(request.minimumVersion).map { (version: $0, request: request) }
        }
        // File names are unique within a pass, so this order has no ties. On equal versions an earlier name ranks
        // higher, which makes it the one `max` returns.
        return ranked.max { lhs, rhs in
            lhs.version == rhs.version ? lhs.request.fileName > rhs.request.fileName : lhs.version < rhs.version
        }?.request
    }

}

// MARK: - Level1JSONReader.checkMinimumDataPackageVersion

extension Level1JsonReader {

    /// Checks a file's header for a `minimumDataPackageVersion` newer than `PhotoClubHubDataVersion.semver` (Data#107).
    ///
    /// The field is optional. If it asks for more than this build, the request is logged and recorded in this file's
    /// entry of `history`, and the file loads anyway. Only this one file is looked at: which request is passed to an
    /// app is decided once the pass is over, by `NewerPackageRequest.pickHighest(of:)`.
    ///
    /// A value that is not a version, such as "three" or an unquoted 3.11, is a mistake in the file rather than a
    /// request: it stops a Debug build and is ignored by a release build, like other malformed Level 1 fields.
    @Sendable static func checkMinimumDataPackageVersion(in jsonRoot: JSON, // full JSON content
                                                         fileName: String, // where it came from
                                                         history: Level1History) { // where to store conclusion
        let jsonMinimumVersion: JSON = jsonRoot["level1Header"]["minimumDataPackageVersion"]
        guard jsonMinimumVersion.exists() else { return }

        guard let minimumVersionText: String = jsonMinimumVersion.string,
              let minimumVersion = DottedVersion(minimumVersionText) else {
            ifDebugFatalError("\(fileName).level1.json has a minimumDataPackageVersion of \(jsonMinimumVersion) " +
                              "that isn't a version like \"3.11.0\", so it is ignored")
            return
        }
        let currentCodeVersionText: String = PhotoClubHubDataVersion.semver

        // Returns quietly if this build is recent enough.
        // It also returns if this build's own version were unreadable, but that can't ship:
        // DottedVersionTests.ownVersionParses would fail on it.
        guard let currentCodeVersion = DottedVersion(currentCodeVersionText),
              currentCodeVersion < minimumVersion else { return }

        history.record(minimumDataPackageVersion: minimumVersionText, for: fileName)
        print("Warning: \(fileName).level1.json asks for Photo Club Hub Data \(minimumVersionText) or newer, " +
              "but this build contains \(currentCodeVersionText). Loading continues with the data as it is.")
    }

}

// MARK: - Level1JSONReader.latestNewerPackageRequest

extension LevelLoader {

    private static let latestNewerPackageRequest = OSAllocatedUnfairLock<NewerPackageRequest?>(initialState: nil)

    /// The highest Data package version that a Level 1 file of the latest `loadAllLevels` pass requested, above the
    /// version of this build, with the name of a file that asked for it; or nil if no file did (Data#107).
    /// When several files ask for that version, the one whose file name comes first alphabetically is given.
    /// Read it after `await loadAllLevels` has returned.
    ///
    /// The data still loaded: this only says that a newer app would show more recent data. The Data package has no
    /// UI, so each app decides how to say that: the iOS app suggests an update to its users (Photo-Club-Hub#899) and
    /// the HTML generator warns its maintainer (Photo-Club-Hub-HTML#282).
    ///
    /// Written when the Level 1 stage of a pass finishes, replacing the value of the previous pass. A static property
    /// rather than a return value, so that any view can read it without the app having to keep the result around.
    public static var newerPackageRequest: NewerPackageRequest? {
        latestNewerPackageRequest.withLock { $0 }
    }

    /// Makes `request` the value of `newerPackageRequest`, even when it is nil, so that a pass without a request
    /// clears the previous pass's one.
    static func publishNewerPackageRequest(_ request: NewerPackageRequest?) {
        latestNewerPackageRequest.withLock { $0 = request }
    }

}
