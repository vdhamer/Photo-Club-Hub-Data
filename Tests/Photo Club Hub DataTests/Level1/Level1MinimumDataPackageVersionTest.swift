//
//  Level1MinimumDataPackageVersionTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 20/11/2026.
//

import Testing      // for macros like @Test
import CoreData     // for NSManagedObjectContext
@testable import Photo_Club_Hub_Data

private let isBeingTested = true

/// Behavior of Level 1 header's `minimumDataPackageVersion` when it's higher than this build's version (Data#107):
/// the file still loads, its request is recorded in the pass's `Level1History`, and the highest request is reported.
///
/// Each test reads its own history, which is why they check the history and not `LevelLoader.newerPackageRequest`:
/// the latter is process-wide, and the test run loads whole passes in parallel.
@MainActor @Suite("Tests the minimumDataPackageVersion header of Level 1 files") struct Level1MinimumVersionTests {

    private let testPersistenceController: PersistenceController

    init () {
        // A private in-memory store per test, set up just like the one in Level1JsonReaderTests.
        testPersistenceController = PersistenceController(inMemory: true)
        let viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        Language.initConstants(context: viewContext)
        OrganizationType.initConstants(context: viewContext)
    }

    /// Loads `fileName` together with everything it includes, and returns that pass's history.
    /// Reads the test bundle only, unless `explicitRemoteURL` points at a file written by the test itself.
    private func load(_ fileName: String, explicitRemoteURL: URL? = nil) async -> Level1History {
        let history = Level1History()

        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = fileName
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        await Level1JsonReader.load(bgContext: bgContext,
                                    fileName: fileName,
                                    isBeingTested: isBeingTested,
                                    useOnlyInBundleFile: explicitRemoteURL == nil,
                                    usedContainer: testPersistenceController.container,
                                    history: history,
                                    explicitRemoteURL: explicitRemoteURL)
        return history
    }

    private func findOrganization(withNickName nickName: String) -> Organization? {
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        let organizations = (try? testPersistenceController.container.viewContext.fetch(fetchRequest)) ?? []
        return organizations.first { $0.nickName == nickName }
    }

    @Test("A higher minimumDataPackageVersion request is recorded along with its file name, and the file still loads")
    func higherVersionIsRecorded() async {
        let history = await load("minimumVersionHighTest")

        #expect(history.newerPackageRequest == NewerPackageRequest(fileName: "minimumVersionHighTest",
                                                                   minimumVersion: "99.0.0"))
        #expect(findOrganization(withNickName: "MinimumHigh")?.fullName == "Minimum High Club")
    }

    @Test("A lower minimumDataPackageVersion is no request")
    func lowerVersionIsNoRequest() async {
        let history = await load("minimumVersionLowTest")

        #expect(history.newerPackageRequest == nil) // no problems found
        #expect(findOrganization(withNickName: "MinimumLow")?.fullName == "Minimum Low Club") // and did load a club
    }

    @Test("A file without a minimumDataPackageVersion is no request")
    func missingVersionIsNoRequest() async {
        let history = await load("IncludeParentTest")

        #expect(history.newerPackageRequest == nil)
        #expect(findOrganization(withNickName: "IncludeChild")?.fullName == "Include Child Club")
    }

    // The rule is "lower than", so a file that asks for exactly this build's version is satisfied. The fixture is
    // written on the fly because the number to ask for changes with every release of the package.
    @Test("A minimumDataPackageVersion equal to the package's own version is no request")
    func equalVersionIsNoRequest() async throws {
        let fileName = "minimumVersionEqualTest"
        let jsonFileContent = """
            { "level1Header": { "minimumDataPackageVersion": "\(PhotoClubHubDataVersion.semver)" },
              "clubs": [ { "idPlus": { "town": "Test Valley",
                                       "fullName": "Minimum Equal Club",
                                       "nickName": "MinimumEqual" },
                           "coordinates": { "latitude": 51.12862, "longitude": 1.51063 },
                           "optional": { } } ] }
            """ // careful: jsonFileContent is just level1.json data, so don't add Swift comments for these lines
        let onlineCopy = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("\(fileName)-\(UUID().uuidString).level1.json") // unique file name
        try jsonFileContent.write(to: onlineCopy, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: onlineCopy) }

        let history = await load(fileName, explicitRemoteURL: onlineCopy)

        #expect(history.newerPackageRequest == nil)
        #expect(findOrganization(withNickName: "MinimumEqual")?.fullName == "Minimum Equal Club")
    }

    // The parent asks for 98.0.0 and loads first. The file it includes asks for 99.0.0 and loads later. Both
    // requests are recorded, and the higher one is reported although it was recorded last. Both files load.
    @Test("Every request of a pass is recorded, and the highest version is reported")
    func highestVersionIsReported() async {
        let history = await load("minimumVersionParentTest")

        #expect(history.newerPackageRequests == [
            NewerPackageRequest(fileName: "minimumVersionHighTest", minimumVersion: "99.0.0"),
            NewerPackageRequest(fileName: "minimumVersionParentTest", minimumVersion: "98.0.0")
        ])
        #expect(history.newerPackageRequest == NewerPackageRequest(fileName: "minimumVersionHighTest",
                                                                   minimumVersion: "99.0.0"))

        #expect(findOrganization(withNickName: "MinimumHigh")?.fullName == "Minimum High Club") // the included file
    }

    @Test("Each pass has its own requests")
    func eachPassIsIndependent() async {
        let firstPass = await load("minimumVersionHighTest")
        let secondPass = await load("minimumVersionLowTest")

        #expect(firstPass.newerPackageRequest == NewerPackageRequest(fileName: "minimumVersionHighTest",
                                                                     minimumVersion: "99.0.0"))
        #expect(secondPass.newerPackageRequest == nil)
    }

    @Test("A minimumDataPackageVersion that is not a version is reported and ignored",
          .usesIfDebugFatalErrorSpy)
    func malformedVersionIsIgnored() async {
        let spy = makeIfDebugFatalErrorSpy() // records the DEBUG-mode trap instead of crashing the test run
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        let history = await load("minimumVersionBadTest")

        #expect(spy.messages.contains {
            $0.contains("minimumVersionBadTest") && $0.contains("minimumDataPackageVersion")
        })
        #expect(history.newerPackageRequest == nil)
        #expect(findOrganization(withNickName: "MinimumBad")?.fullName == "Minimum Bad Club") // the file still loads
    }
}
