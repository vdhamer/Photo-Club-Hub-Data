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

    private let store = LogbookTestStore()

    // MARK: - Which entry decides whether an organization is former

    @Test("The last entry with the key decides, and an entry without the key changes nothing")
    func lastKeyDecides() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let club = try store.organization("Last Key Club")
        // The deciding entry is dated a day before the one it overrules, so a date-based rule would give false.
        #expect(club.isFormerOrganization == true)
        #expect(club.logEntries.map(\.isFormerOrganization) == [true, false, true, nil])
    }

    @Test("An organization without a logbook is not former") func noLogbookIsNotFormer() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let club = try store.organization("No Log Club")
        #expect(club.isFormerOrganization == false)
        #expect(club.logEntries.isEmpty)
    }

    @Test("Either JSON keyword works on either kind of organisation") func keysAreAliases() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        #expect(try store.organization("Museum Key Club").isFormerOrganization == true)
        #expect(try store.organization("Club Key Museum").isFormerOrganization == true)
        #expect(try store.organization("Closed Museum").isFormerOrganization == true)
    }

    // Both records have isFormerClub false and isFormerMuseum true in one entry.
    @Test("The record's own key wins if one entry has both keys with different values") func ownKeyWins() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        #expect(try store.organization("Both Keys Club").isFormerOrganization == false)
        #expect(try store.organization("Both Keys Museum").isFormerOrganization == true)
    }

    // MARK: - The fields of an entry

    @Test("The entries keep their array order and their values") func entriesKeepOrderAndValues() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let entries = try store.organization("Last Key Club").logEntries
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
        await store.loadLevel1File(fileName: "logbookTest")
        let date = try #require(try store.organization("Last Key Club").logEntries.first).date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 9)
        #expect(components.day == 12)
        #expect(components.hour == 0)
    }

    // MARK: - Loading a changed file

    @Test("Changed text updates the same row, and a shorter array deletes the extra rows")
    func changedLogUpdatesInPlace() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let firstRowBefore = try #require(try store.organization("Changing Log Club").logEntries.first).objectID
        #expect(try store.organization("Changing Log Club").isFormerOrganization == true)

        await store.loadLevel1File(fileName: "logbookChangedTest")
        let club = try store.organization("Changing Log Club")
        #expect(club.logEntries.map(\.text) == ["Second version of this text.", "Second entry."])
        #expect(club.logEntries.first?.objectID == firstRowBefore)
        #expect(club.isFormerOrganization == false) // the entry holding the key is gone
    }

    @Test("Removing the logbook clears the state and the rows, and removing the list clears the bad websites")
    func removedLogClearsEverything() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        #expect(try store.organization("Removed Log Club").isFormerOrganization == true)
        #expect(try store.organization("Removed Log Club").badWebsites.count == 1)

        await store.loadLevel1File(fileName: "logbookChangedTest")
        let club = try store.organization("Removed Log Club")
        #expect(club.isFormerOrganization == false)
        #expect(club.logEntries.isEmpty)
        #expect(club.badWebsites.isEmpty)
        // Deleted, not just unlinked: an unlinked row would stay in the store, invisible to the club.
        #expect(store.allLogEntries().allSatisfy { $0.organization_ != nil })
    }

    @Test("Loading the same file again leaves the rows as they were") func reloadKeepsRows() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let rowsBefore = Set(store.allLogEntries().map(\.objectID))
        #expect(rowsBefore.isEmpty == false)

        await store.loadLevel1File(fileName: "logbookTest")
        store.viewContext.refreshAllObjects()
        #expect(Set(store.allLogEntries().map(\.objectID)) == rowsBefore)
    }

    // MARK: - Bad websites

    @Test("A website on the list isn't stored, whatever its case or trailing slash")
    func listedWebsiteIsNotStored() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        // Hijacked Club: the file has a slash, the list has capitals.
        #expect(try store.organization("Hijacked Club").organizationWebsite == nil)
        #expect(try store.organization("Closed Museum").organizationWebsite == nil) // list has a slash, file doesn't
    }

    @Test("A website that isn't on the list stays") func unlistedWebsiteStays() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let club = try store.organization("Good Website Club")
        #expect(club.organizationWebsite == URL(string: "https://good.example.org/"))
        #expect(club.badWebsites.map(\.absoluteString) == ["https://old.example.org/", "https://older.example.org/"])
    }

    // The store keeps each bad website exactly as the file has it, so that a writer can put the file back unchanged
    // (Data#63). This checks badWebsites_, not the badWebsites wrapper, because the wrapper parses each one as a URL.
    // The space is only there to catch a reader that parses the URL before storing it, which would turn it into %20.
    @Test("A bad website is stored as written") func badWebsiteIsStoredAsWritten() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        #expect(try store.organization("Unusual Bad Website Club").badWebsites_ == "https://old.example.org/my page")
    }

    @Test("A stored website is cleared once the list holds it") func storedWebsiteIsCleared() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        #expect(try store.organization("Later Bad Website Club").organizationWebsite != nil) // holds a string

        await store.loadLevel1File(fileName: "logbookChangedTest")
        #expect(try store.organization("Later Bad Website Club").organizationWebsite == nil) // holds nil
    }

    // The Level 2 reader stores a club's website through this same call, with no logbook fields,
    // so this call stands in for a Level 2 file that supplies a website that Level 1 lists as bad.
    @Test("A later caller can't store a website that is on the list")
    func laterCallerCantStoreListedWebsite() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let bgContext = store.makeBackgroundContext()
        // Written differently from the list in the fixture, which canonicalString must see through.
        let listedWebsite = URL(string: "https://WWW.hijacked.example.org/")
        _ = Organization.findCreateUpdate(
            context: bgContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(fullName: "Hijacked Club", town: "Logtown", nickname: "hijackedClub"),
            optionalFields: OrganizationOptionalFields(organizationWebsite: listedWebsite)
        ) // synchronous: it returns after the change has been saved, so the next line can safely read it
        #expect(try store.organization("Hijacked Club").organizationWebsite == nil)
    }

    // The list holds "HTTPS://WWW.HIJACKED.EXAMPLE.ORG": a different scheme and no "www." is still the same website.
    @Test("A listed website is recognized without its scheme or www")
    func listedWebsiteIsRecognizedInOtherSpellings() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        for spelling in ["http://hijacked.example.org", "hijacked.example.org", "www.Hijacked.example.org/"] {
            let bgContext = store.makeBackgroundContext()
            _ = Organization.findCreateUpdate(
                context: bgContext,
                organizationTypeEnum: .club,
                idPlus: OrganizationIdPlus(fullName: "Hijacked Club", town: "Logtown", nickname: "hijackedClub"),
                optionalFields: OrganizationOptionalFields(organizationWebsite: URL(string: spelling))
            )
            #expect(try store.organization("Hijacked Club").organizationWebsite == nil, "\(spelling)")
        }
    }

    // MARK: - Other callers

    @Test("A call with default fields leaves the logbook, the state and the bad websites alone")
    func defaultFieldsChangeNothing() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let bgContext = store.makeBackgroundContext()
        _ = Organization.findCreateUpdate(
            context: bgContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(fullName: "Removed Log Club", town: "Logtown", nickname: "removedLogClub")
        )
        let club = try store.organization("Removed Log Club")
        #expect(club.isFormerOrganization == true)
        #expect(club.logEntries.count == 1)
        #expect(club.badWebsites.count == 1)
    }

    // MARK: - Leaving out former organizations (#891)

    @Test("currentPredicate leaves out former organizations") func currentPredicateLeavesOutFormer() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = Organization.currentPredicate // organizations without the isFormerOrganization ones
        let fullNames: Set<String> = Set(try store.viewContext.fetch(fetchRequest).map(\.fullName))
        #expect(fullNames.contains("No Log Club"))
        #expect(fullNames.contains("Last Key Club") == false) // former
        #expect(fullNames.contains("Closed Museum") == false) // former, and a museum
    }

    @Test("currentOrganizationPredicate leaves out the portfolios of former clubs")
    func currentOrganizationPredicateLeavesOutFormer() async throws {
        await store.loadLevel1File(fileName: "logbookTest")
        let bgContext = store.makeBackgroundContext()
        let photographer = Photographer.findCreateUpdate(context: bgContext,
                                                         personName: PersonName(givenName: "Example",
                                                                                infixName: "",
                                                                                familyName: "Member"),
                                                         optionalFields: PhotographerOptionalFields())
        for fullName in ["Last Key Club", "No Log Club"] {
            let club = try Organization.find(context: bgContext,
                                             organizationID: OrganizationID(fullName: fullName, town: "Logtown"))
            _ = MemberPortfolio.findCreateUpdate(bgContext: bgContext, organization: club, photographer: photographer)
        }
        try bgContext.performAndWait { try bgContext.save() } // like the Level 2 reader, which saves at its end

        store.viewContext.refreshAllObjects()
        let fetchRequest: NSFetchRequest<MemberPortfolio> = MemberPortfolio.fetchRequest()
        fetchRequest.predicate = MemberPortfolio.currentOrganizationPredicate
        let portfolios: [MemberPortfolio] = try store.viewContext.fetch(fetchRequest)
        #expect(portfolios.map(\.organization.fullName) == ["No Log Club"])
    }

}
