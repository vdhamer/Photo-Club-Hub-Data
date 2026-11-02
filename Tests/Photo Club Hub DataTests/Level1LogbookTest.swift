//
//  Level1LogbookTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 31/10/2026.
//

import Testing      // for macros like @Test
@testable import Photo_Club_Hub_Data
import CoreData     // for NSManagedObjectContext
import CoreLocation // for CLLocationCoordinate2D

// The spec in Data#91: how `logbook` and `badWebsites` in a Level 1 file end up in the CoreData store.
@MainActor @Suite("Tests the logbook and bad websites in a Level 1 file") struct Level1LogbookTests {

    private let testPersistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext

    init () {
        testPersistenceController = PersistenceController(inMemory: true) // inMemory is important for isolation
        viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // The empty store lacks the constant records the app prefills at launch; so we insert them here.
        Language.initConstants(context: viewContext) // e.g. NL
        OrganizationType.initConstants(context: viewContext) // e.g. club
    }

    private func makeBackgroundContext() -> NSManagedObjectContext {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = "Level1LogbookTest"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true
        return bgContext
    }

    private func loadLevel1File(fileName: String) async {
        await Level1JsonReader.load(bgContext: makeBackgroundContext(),
                                    fileName: fileName,
                                    isBeingTested: true,
                                    useOnlyInBundleFile: true,
                                    usedContainer: testPersistenceController.container)
    }

    // Refreshes first, because the load changed the store through another context.
    private func organization(_ fullName: String) throws -> Organization {
        viewContext.refreshAllObjects()
        return try Organization.find(context: viewContext,
                                     organizationID: OrganizationID(fullName: fullName, town: "Logtown"))
    }

    private func allLogEntries() -> [LogEntry] {
        (try? viewContext.fetch(LogEntry.fetchRequest())) ?? []
    }

    // MARK: - Which entry decides whether an organization is former

    @Test("The last entry with the key decides, and an entry without the key changes nothing")
    func lastKeyDecides() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let club = try organization("Last Key Club")
        // The deciding entry is dated a day before the one it overrules, so a date-based rule would give false.
        #expect(club.isFormerOrganization == true)
        #expect(club.logEntries.map(\.isFormerOrganization) == [true, false, true, nil])
    }

    @Test("An organization without a logbook is not former") func noLogbookIsNotFormer() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let club = try organization("No Log Club")
        #expect(club.isFormerOrganization == false)
        #expect(club.logEntries.isEmpty)
    }

    @Test("Either JSON keyword works on either kind of organisation") func keysAreAliases() async throws {
        await loadLevel1File(fileName: "logbookTest")
        #expect(try organization("Museum Key Club").isFormerOrganization == true)
        #expect(try organization("Club Key Museum").isFormerOrganization == true)
        #expect(try organization("Closed Museum").isFormerOrganization == true)
    }

    // Both records have isFormerClub false and isFormerMuseum true in one entry.
    @Test("The record's own key wins if one entry has both keys with different values") func ownKeyWins() async throws {
        await loadLevel1File(fileName: "logbookTest")
        #expect(try organization("Both Keys Club").isFormerOrganization == false)
        #expect(try organization("Both Keys Museum").isFormerOrganization == true)
    }

    // MARK: - The fields of an entry

    @Test("The entries keep their array order and their values") func entriesKeepOrderAndValues() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let entries = try organization("Last Key Club").logEntries
        // logEntries sorts by position, so checking the positions alone would pass whatever the order.
        // The third entry is dated a day before the second, so sorting by date would fail this test.
        #expect(entries.map(\.text) == ["Website went down.",
                                        "Still meeting.",
                                        "Disbanded after all.",
                                        "Website still down."]) // order in JSON array
        #expect(entries.map(\.originalDataSourceLevel) == [1, 1, 1, 1]) // all loaded by loadLevel1File
        #expect(entries[1].author == "afdeling contact")
        #expect(entries[1].organization.fullName == "Last Key Club")
    }

    @Test("A date is the calendar day in GMT") func dateIsCalendarDayInGMT() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let date = try #require(try organization("Last Key Club").logEntries.first).date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 9)
        #expect(components.day == 12)
        #expect(components.hour == 0)
    }

    // MARK: - Entries that break the rules

    // The tests below install a spy, which makes ifDebugFatalError record its message and return.
    // That is what a Release build does, so they show both builds: Debug stops, and Release keeps the entry.
    // Every other test loads files with complete entries and has no spy, so a false alarm would stop the test run.

    @Test("A missing date stops a Debug build, and a Release build keeps the entry and its key",
          .usesIfDebugFatalErrorSpy)
    func missingDateStopsDebugAndKeepsEntry() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Log entry in No Date Club lacks a required field") })

        let club = try organization("No Date Club")
        #expect(club.isFormerOrganization == true)
        #expect(club.logEntries.count == 1)
        #expect(club.logEntries.first?.date_ == nil)
        #expect(club.logEntries.first?.date == Date.distantPast)
    }

    @Test("A malformed date stops a Debug build, and a Release build keeps the entry and its key",
          .usesIfDebugFatalErrorSpy)
    func malformedDateStopsDebugAndKeepsEntry() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Failed to decode date from 29-10-2026") })

        let club = try organization("Malformed Date Club")
        #expect(club.isFormerOrganization == true)
        #expect(club.logEntries.count == 1)
        #expect(club.logEntries.first?.date_ == nil)
    }

    @Test("A blank or missing author or text stops a Debug build, and a Release build shows a placeholder",
          .usesIfDebugFatalErrorSpy)
    func blankFieldsStopDebugAndShowPlaceholder() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await loadLevel1File(fileName: "logbookBadEntriesTest")
        // Each entry breaks exactly one rule, so each of the conditions in checkRequiredFields() must fire on its own:
        // author missing, author blank, text missing, text blank. The missing date is in No Date Club.
        #expect(spy.messages.filter { $0.contains("Log entry in Blank Fields Club") }.count == 4)

        let entries = try organization("Blank Fields Club").logEntries
        #expect(entries.map(\.author_) == [nil, "", "generator", "generator"])
        #expect(entries.map(\.author) == ["Author?", "Author?", "generator", "generator"])
        #expect(entries.map(\.text_) == ["The author is missing.", "The author is blank.", nil, "   "])
        #expect(entries.map(\.text) == ["The author is missing.", "The author is blank.", "Text?", "Text?"])
    }

    @Test("A quoted \"true\" stops a Debug build, and a Release build ignores it",
          .usesIfDebugFatalErrorSpy)
    func quotedFlagStopsDebugAndIsIgnored() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Log entry in Quoted Flag Club has an isFormerClub") })

        let club = try organization("Quoted Flag Club")
        #expect(club.isFormerOrganization == false)
        #expect(club.logEntries.first?.isFormerOrganization == nil)
    }

    // MARK: - Loading a changed file

    @Test("Changed text updates the same row, and a shorter array deletes the extra rows")
    func changedLogUpdatesInPlace() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let firstRowBefore = try #require(try organization("Changing Log Club").logEntries.first).objectID
        #expect(try organization("Changing Log Club").isFormerOrganization == true)

        await loadLevel1File(fileName: "logbookChangedTest")
        let club = try organization("Changing Log Club")
        #expect(club.logEntries.map(\.text) == ["Second version of this text.", "Second entry."])
        #expect(club.logEntries.first?.objectID == firstRowBefore)
        #expect(club.isFormerOrganization == false) // the entry holding the key is gone
    }

    @Test("Removing the logbook clears the state and the rows, and removing the list clears the bad websites")
    func removedLogClearsEverything() async throws {
        await loadLevel1File(fileName: "logbookTest")
        #expect(try organization("Removed Log Club").isFormerOrganization == true)
        #expect(try organization("Removed Log Club").badWebsites.count == 1)

        await loadLevel1File(fileName: "logbookChangedTest")
        let club = try organization("Removed Log Club")
        #expect(club.isFormerOrganization == false)
        #expect(club.logEntries.isEmpty)
        #expect(club.badWebsites.isEmpty)
        // Deleted, not just unlinked: an unlinked row would stay in the store, invisible to the club.
        #expect(allLogEntries().allSatisfy { $0.organization_ != nil })
    }

    @Test("Loading the same file again leaves the rows as they were") func reloadKeepsRows() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let rowsBefore = Set(allLogEntries().map(\.objectID))
        #expect(rowsBefore.isEmpty == false)

        await loadLevel1File(fileName: "logbookTest")
        viewContext.refreshAllObjects()
        #expect(Set(allLogEntries().map(\.objectID)) == rowsBefore)
    }

    // MARK: - Bad websites

    @Test("A website on the list isn't stored, whatever its case or trailing slash")
    func listedWebsiteIsNotStored() async throws {
        await loadLevel1File(fileName: "logbookTest")
        #expect(try organization("Hijacked Club").organizationWebsite == nil) // file has a slash, list has capitals
        #expect(try organization("Closed Museum").organizationWebsite == nil) // list has a slash, file doesn't
    }

    @Test("A website that isn't on the list stays") func unlistedWebsiteStays() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let club = try organization("Good Website Club")
        #expect(club.organizationWebsite == URL(string: "https://good.example.org/"))
        #expect(club.badWebsites.map(\.absoluteString) == ["https://old.example.org/", "https://older.example.org/"])
    }

    // The store keeps each bad website exactly as the file has it, so that a writer can put the file back unchanged
    // (Data#63). This checks badWebsites_, not the badWebsites wrapper, because the wrapper parses each one as a URL.
    // The space is only there to catch a reader that parses the URL before storing it, which would turn it into %20.
    @Test("A bad website is stored as written") func badWebsiteIsStoredAsWritten() async throws {
        await loadLevel1File(fileName: "logbookTest")
        #expect(try organization("Unusual Bad Website Club").badWebsites_ == "https://old.example.org/my page")
    }

    @Test("A stored website is cleared once the list holds it") func storedWebsiteIsCleared() async throws {
        await loadLevel1File(fileName: "logbookTest")
        #expect(try organization("Later Bad Website Club").organizationWebsite != nil) // holds a string

        await loadLevel1File(fileName: "logbookChangedTest")
        #expect(try organization("Later Bad Website Club").organizationWebsite == nil) // holds nil
    }

    // The Level 2 reader stores a club's website through this same call, with no logbook fields,
    // so this call stands in for a Level 2 file that supplies a website that Level 1 lists as bad.
    @Test("A later caller can't store a website that is on the list")
    func laterCallerCantStoreListedWebsite() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let bgContext = makeBackgroundContext()
        // Written differently from the list in the fixture, which canonicalString must see through.
        let listedWebsite = URL(string: "https://WWW.hijacked.example.org/")
        _ = Organization.findCreateUpdate(
            context: bgContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(fullName: "Hijacked Club", town: "Logtown", nickname: "hijackedClub"),
            optionalFields: OrganizationOptionalFields(organizationWebsite: listedWebsite)
        ) // synchronous: it returns after the change has been saved, so the next line can safely read it
        #expect(try organization("Hijacked Club").organizationWebsite == nil)
    }

    // The list holds "HTTPS://WWW.HIJACKED.EXAMPLE.ORG": a different scheme and no "www." is still the same website.
    @Test("A listed website is recognized without its scheme or www")
    func listedWebsiteIsRecognizedInOtherSpellings() async throws {
        await loadLevel1File(fileName: "logbookTest")
        for spelling in ["http://hijacked.example.org", "hijacked.example.org", "www.Hijacked.example.org/"] {
            let bgContext = makeBackgroundContext()
            _ = Organization.findCreateUpdate(
                context: bgContext,
                organizationTypeEnum: .club,
                idPlus: OrganizationIdPlus(fullName: "Hijacked Club", town: "Logtown", nickname: "hijackedClub"),
                optionalFields: OrganizationOptionalFields(organizationWebsite: URL(string: spelling))
            )
            #expect(try organization("Hijacked Club").organizationWebsite == nil, "\(spelling)")
        }
    }

    // MARK: - Other callers

    @Test("A call with default fields leaves the logbook, the state and the bad websites alone")
    func defaultFieldsChangeNothing() async throws {
        await loadLevel1File(fileName: "logbookTest")
        let bgContext = makeBackgroundContext()
        _ = Organization.findCreateUpdate(
            context: bgContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(fullName: "Removed Log Club", town: "Logtown", nickname: "removedLogClub")
        )
        let club = try organization("Removed Log Club")
        #expect(club.isFormerOrganization == true)
        #expect(club.logEntries.count == 1)
        #expect(club.badWebsites.count == 1)
    }

}
