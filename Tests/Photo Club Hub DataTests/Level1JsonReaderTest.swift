//
//  Level1JsonReaderTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 30/06/2026.
//

import Testing // for macros like @Test
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

private let isBeingTested = true

// These tests used to depend on execution order, because every load shared one process-global
// visited-file guard: two of them load the same file ("clubTemplatesTest"), so interleaved bodies could
// mark it "visited" mid-way through each other and fire the duplicate-file ifDebugFatalError. Each load
// pass now creates its own Level1History (Data#12), so that coupling is gone — as is the note that said
// not to migrate these to `await load(...)` until the guard was injectable (#760).
// Isolation from the app's concurrent background loading comes from the per-test IN-MEMORY store.
@MainActor @Suite("Tests the Level 1 JSON reader") struct Level1JsonReaderTests {

    // MARK: - Init

    private let testPersistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext

    init () {
        // Each test gets its own private in-memory store so the app's concurrent background data-loading
        // into PersistenceController.shared cannot pollute the Organization counts below. Swift Testing
        // creates a fresh suite instance (and thus a fresh init) per test, so the store is effectively
        // per-test — no deletion or cross-test isolation needed.
        testPersistenceController = PersistenceController(inMemory: true) // inMemory is important for isolation
        viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // The empty store lacks the constant records the app inserts at launch; so we insert them here.
        // Level1 organizations reference OrganizationType, so OrganizationType (and Language) must exist first.
        // Must run on the main-queue viewContext (initConstants does a bare save()). See #749.
        Language.initConstants(context: viewContext)
        OrganizationType.initConstants(context: viewContext)
    }

    // Makes a background context wired up the same way the app's Level 1 loader configures one.
    private func makeBackgroundContext(named name: String) -> NSManagedObjectContext {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = name
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true
        return bgContext
    }

    // FetchAndProcessFile does its work asynchronously on `bgContext.perform { }`.
    // For a file without Includes the entire parse-and-save runs inside that single block
    // on the context's serial queue, so enqueueing an empty `performAndWait` afterwards acts as a barrier:
    // it cannot run until the load block has finished.
    // (Files WITH includes spawn further work on other contexts — includeLoadsIntoInjectedStore()
    // below covers that case by awaiting Level1JsonReader.load(...) instead.)
    private func waitForLoad(on bgContext: NSManagedObjectContext) {
        bgContext.performAndWait { }
    }

    // Fetches every Organization currently in stock in the in-memory store.
    private func allOrganizations() -> [Organization] {
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        return (try? viewContext.fetch(fetchRequest)) ?? []
    }

    // MARK: - Tests

    // Read clubTemplatesTest.level1.json (2 clubs, no museums, no includes) and verify both clubs land
    // with the right identity, and that the right club's optional fotobondNumber is parsed.
    @Test("Parse clubTemplatesTest.level1.json") func clubTemplatesParse() {
        let bgContext = makeBackgroundContext(named: "clubTemplatesTest")
        #expect(allOrganizations().isEmpty) // fresh store: initConstants doesn't insert Organization

        _ = Level1JsonReader(bgContext: bgContext,
                             fileName: "clubTemplatesTest",
                             isBeingTested: isBeingTested,
                             useOnlyInBundleFile: true)
        waitForLoad(on: bgContext)

        let organizations = allOrganizations()
        #expect(organizations.count == 2) // the 2 organizations in the JSON file
        #expect(organizations.allSatisfy { organization in // both organizations are Clubs
            organization.organizationType.organizationTypeName == OrganizationTypeEnum.club.rawValue
        })

        // The "maximal" club has a Dutch Fotobond number; verify this number survives a round-trip.
        let templateMax = organizations.first { $0.nickName == "TemplateMax" }
        #expect(templateMax != nil)
        #expect(templateMax?.fullName == "Template Club With Maximal Data")
        #expect(templateMax?.town == "Rotterdam")
        #expect(templateMax?.fotobondClubNumber?.id == 9999)

        // The "minimal" club has only a level2URL; it must have no Fotobond number.
        let templateMin = organizations.first { $0.nickName == "TemplateMin" }
        #expect(templateMin != nil)
        #expect(templateMin?.town == "Amsterdam")
        #expect(templateMin?.fotobondClubNumber?.id == nil)
    }

    // Read museumsTest.level1.json (2 museums, no clubs, no includes)
    // and verify that the reader correctly populates Organizations of type .museum.
    @Test("Parse museumsTest.level1.json") func museumsGBParse() {
        let bgContext = makeBackgroundContext(named: "museumsTest")
        #expect(allOrganizations().isEmpty)

        _ = Level1JsonReader(bgContext: bgContext,
                             fileName: "museumsTest",
                             isBeingTested: isBeingTested,
                             useOnlyInBundleFile: true)
        waitForLoad(on: bgContext)

        let organizations = allOrganizations()
        #expect(organizations.count == 2) // exactly the 2 museums in the file
        #expect(organizations.allSatisfy {
            $0.organizationType.organizationTypeName == OrganizationTypeEnum.museum.rawValue
        })

        let vaOrganization = organizations.first { $0.nickName == "V&A London" }
        #expect(vaOrganization != nil)
        #expect(vaOrganization?.fullName == "The Victoria & Albert Museum")
        #expect(vaOrganization?.town == "London")
    }

    // Loading the same file twice must not create duplicate Organizations: findCreateUpdate
    // matches on idPlus (name + town), so the second load updates rather than duplicates.
    @Test("Reloading the same file is idempotent") func reloadIsIdempotent() {
        let bgContext = makeBackgroundContext(named: "clubTemplatesReloadTest")

        _ = Level1JsonReader(bgContext: bgContext,
                             fileName: "clubTemplatesTest",
                             isBeingTested: isBeingTested,
                             useOnlyInBundleFile: true)
        waitForLoad(on: bgContext)
        #expect(allOrganizations().count == 2)

        // Each load pass owns its own visited guard, so the second load is processed rather than
        // short-circuited — which is what exercises findCreateUpdate's de-duplication.
        _ = Level1JsonReader(bgContext: bgContext,
                             fileName: "clubTemplatesTest",
                             isBeingTested: isBeingTested,
                             useOnlyInBundleFile: true)
        waitForLoad(on: bgContext)
        #expect(allOrganizations().count == 2) // still 2, not 4
    }

    // Read IncludeParent.level1.json, which has no organizations of its own but includes
    // IncludeChild.level1.json (a leaf with one uniquely-named club). This verifies that the
    // `usedContainer:` seam routes an included file's load into this test's in-memory store.
    //
    // These two test data files exist only for this test. That matters:
    //   * The include tree is ACYCLIC — the cyclic case (recursionA ⇄ recursionB) is exercised end-to-end
    //     by cyclicIncludeTerminates() below, which installs an IfDebugFatalErrorSpy so the loop guard's
    //     DEBUG-mode fatalError is recorded instead of crashing the test run.
    //   * The file names are ones the APP never loads, so they can't collide with the app's concurrent
    //     background loading in the shared (global) level1History — a collision there also triggers a fatalError
    //     as a "duplicate file in Include tree".
    //
    // Included files load asynchronously on contexts this test doesn't own, so the test awaits
    // Level1JsonReader.load(...), which returns only after the whole Include tree — including the
    // IncludeChild save — has completed (issue #760). The `await` IS the happens-before guarantee; no
    // NotificationCenter spying, no unstructured Task {}, no Task.yield() timing hacks.
    @Test("An included file is loaded into the injected store")
    func includeLoadsIntoInjectedStore() async {

        let bgContext = makeBackgroundContext(named: "IncludeParentTest")

        await Level1JsonReader.load(bgContext: bgContext,
                                    fileName: "IncludeParent",
                                    isBeingTested: isBeingTested,
                                    useOnlyInBundleFile: true,
                                    usedContainer: testPersistenceController.container)
        // ^ usedContainer routes the included files' loads into the test's in-memory store

        // The club from the *included* IncludeChild.level1.json must now be in the injected store.
        let club = allOrganizations().first { $0.nickName == "IncludeChild" }
        #expect(club != nil)
        #expect(club?.fullName == "Include Child Club")
        #expect(club?.town == "Test Valley")
    }

    // Read recursionA.level1.json, which Includes recursionB.level1.json, which in turn Includes
    // recursionA.level1.json again — a deliberate A ⇄ B cycle. The level1History guard must detect
    // the revisit of recursionA and cut the recursion short instead of looping forever.
    //
    // In a DEBUG (test) build, this guard reacts with ifDebugFatalError, a hard fatalError that would
    // kill the test run. So this test installs an IfDebugFatalErrorSpy: while installed,
    // ifDebugFatalError records its message and returns (the RELEASE-mode path) instead of crashing.
    // As a bonus, the spy lets the test assert that the loop guard actually fired.
    //
    // The .timeLimit is the "terminates" assertion: if the loop guard ever regresses, the include
    // recursion would otherwise hang the test and run indefinitely rather than fail.
    @Test("A cyclic Include (recursionA ⇄ recursionB) terminates",
          .timeLimit(.minutes(1)))
    func cyclicIncludeTerminates() async {

        let spy = makeIfDebugFatalErrorSpy() // keeps the loop guard's fatalError from killing the test run
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        let bgContext = makeBackgroundContext(named: "recursionATest")
        await Level1JsonReader.load(bgContext: bgContext,
                                    fileName: "recursionA",
                                    isBeingTested: isBeingTested,
                                    useOnlyInBundleFile: true,
                                    usedContainer: testPersistenceController.container)

        // Reaching this line at all means the A → B → A recursion terminated (the await returned).
        // The loop guard must have fired when recursionA was revisited:
        #expect(spy.messages.contains { $0.contains("Infinite loop or duplicate file") })

        // recursionB itself was still processed normally — exactly once: its lone club is in the store.
        #expect(allOrganizations().filter { $0.nickName == "Antartica" }.count == 1)
    }

}
