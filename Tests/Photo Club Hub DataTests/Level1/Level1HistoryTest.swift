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

    // Merging the recorded requests (Data#107). Files load concurrently, so recording order is arbitrary:
    // each test records in both orders and expects the same answer.
    @Test("No request recorded means no request reported")
    func noRequestIsNil() {

        let history = Level1History()
        #expect(history.isVisitedBefore(fileName: "leafA") == false)
        #expect(history.newerPackageRequests.isEmpty)
        #expect(history.newerPackageRequest == nil)
    }

    // Recording a version must not disturb the visited-file guard, which shares the same entries.
    @Test("Recording a version keeps the file visited, and leaves other files unvisited")
    func recordingKeepsGuardIntact() {

        let history = Level1History()
        #expect(history.isVisitedBefore(fileName: "leafA") == false)
        history.record(minimumDataPackageVersion: "4.0", for: "leafA")

        #expect(history.isVisitedBefore(fileName: "leafA") == true)
        #expect(history.isVisitedBefore(fileName: "leafB") == false)
        #expect(history.newerPackageRequests == [NewerPackageRequest(fileName: "leafA", minimumVersion: "4.0")])
    }

    @Test("The highest version is reported, compared as numbers, whatever the recording order",
          arguments: [false, true])
    func highestVersionWins(reversed: Bool) {

        let leafA = NewerPackageRequest(fileName: "leafA", minimumVersion: "3.9.0") // the higher one as text
        let leafB = NewerPackageRequest(fileName: "leafB", minimumVersion: "3.11.0") // the higher one as numbers
        let history = Level1History()
        for request in reversed ? [leafB, leafA] : [leafA, leafB] {
            history.record(minimumDataPackageVersion: request.minimumVersion, for: request.fileName)
        }

        #expect(history.newerPackageRequest == leafB)
        #expect(history.newerPackageRequests == [leafA, leafB]) // sorted by file name
    }

    @Test("Of several files asking for the same highest version, the first by name is reported",
          arguments: [false, true])
    func tieGoesToFirstName(reversed: Bool) {

        let leafB = NewerPackageRequest(fileName: "leafB", minimumVersion: "4.0")
        let leafD = NewerPackageRequest(fileName: "leafD", minimumVersion: "4.0.0") // equal to "4.0"
        let history = Level1History()
        for request in reversed ? [leafD, leafB] : [leafB, leafD] {
            history.record(minimumDataPackageVersion: request.minimumVersion, for: request.fileName)
        }

        #expect(history.newerPackageRequest == leafB)
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
