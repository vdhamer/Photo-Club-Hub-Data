//
//  Level1HistoryTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 30/06/2026.
//

import Testing
@testable import Photo_Club_Hub_Data

// Level1History is the loop/duplicate guard used by Level1JsonReader: each load of a level1.json file
// is recorded the first time it is visited.
// It uses this to guard that an Include tree (e.g. recursionA → recursionB → recursionA → ...) cannot
// load the same file twice or recurse forever.
//
// These tests construct their own Level1History instances, which is now also how the loaders use it:
// one instance per load pass rather than a process-wide singleton (Data#12).
//
// The tests used to be gated behind `.enabled(if:)` traits because Level1History was annotated
// @available(iOS 18, macOS 15, *) for its use of `Mutex`, while this package supports iOS 17. It now uses
// OSAllocatedUnfairLock (iOS 16+) so that it can appear in un-gated public signatures,
// and the availability gating is gone with it.
@Suite("Tests the Level1History recursion/duplicate guard") struct Level1HistoryTests {

    // The first visit to a file finds "not yet visited"; the second visit to the SAME file is "visited".
    @Test("A file is unvisited the first time and visited the second time")
    func recordsFirstVisit() {

        let history = Level1History()
        #expect(history.isVisitedBefore(fileName: "root") == false) // first encounter
        #expect(history.isVisitedBefore(fileName: "root") == true)  // already recorded
    }

    // Distinct file names are tracked independently — visiting one does not affect another.
    @Test("Different file names are tracked independently")
    func distinctNamesAreIndependent() {

        let history = Level1History()
        #expect(history.isVisitedBefore(fileName: "fileA") == false)
        #expect(history.isVisitedBefore(fileName: "fileB") == false) // not affected by fileA
        #expect(history.isVisitedBefore(fileName: "fileA") == true)  // fileA is now known
        #expect(history.isVisitedBefore(fileName: "fileB") == true)  // fileB is now known
    }

    // clear() resets the guard: a previously visited file is considered unvisited again.
    @Test("clear() resets the visited history")
    func clearResetsHistory() {

        let history = Level1History()
        #expect(history.isVisitedBefore(fileName: "museums") == false)
        #expect(history.isVisitedBefore(fileName: "museums") == true)

        history.clear()

        #expect(history.isVisitedBefore(fileName: "museums") == false) // all previous visits are cleared by clear()
    }

    // Matching is case-sensitive: names differing-only-in-case are treated as different files.
    // (Documents current behavior — file names in the Include tree are used verbatim.)
    @Test("File-name matching is case-sensitive")
    func matchingIsCaseSensitive() {

        let history = Level1History()
        #expect(history.isVisitedBefore(fileName: "Museums") == false)
        #expect(history.isVisitedBefore(fileName: "museums") == false) // different case → different file
    }

}
