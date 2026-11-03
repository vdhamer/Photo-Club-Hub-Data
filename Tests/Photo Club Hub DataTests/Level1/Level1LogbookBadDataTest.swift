//
//  Level1LogbookBadDataTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 03/11/2026.
//

import Testing      // for macros like @Test
@testable import Photo_Club_Hub_Data
import CoreData     // for NSManagedObjectContext

// The rules in Data#91 for data that is wrong: a Debug build stops, and a Release build keeps what it can.
@MainActor @Suite("Tests how the logbook and bad websites handle data that breaks the rules")
struct Level1LogbookBadDataTests {

    private let store = LogbookTestStore()

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

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Log entry in No Date Club has no date") })

        let club = try store.organization("No Date Club")
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

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Illegal date value \"29-10-2026\"") })

        let club = try store.organization("Malformed Date Club")
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

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        // Each entry breaks exactly one rule, so each of the checks in checkRequiredKeys() must fire on its own:
        // author missing, author blank, text missing, text blank. The missing date is in No Date Club.
        #expect(spy.messages.filter { $0.contains("Log entry in Blank Fields Club has no author") }.count == 2)
        #expect(spy.messages.filter { $0.contains("Log entry in Blank Fields Club has no text") }.count == 2)

        let entries = try store.organization("Blank Fields Club").logEntries
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

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Log entry in Quoted Flag Club has an isFormerClub") })

        let club = try store.organization("Quoted Flag Club")
        #expect(club.isFormerOrganization == false)
        #expect(club.logEntries.first?.isFormerOrganization == nil)
    }

    // One day back is allowed, and Last Key Club in logbookTest has such an entry, loaded without a spy.
    @Test("A date more than a day before the entry above it stops a Debug build, and a Release build keeps both",
          .usesIfDebugFatalErrorSpy)
    func dateGoingBackStopsDebug() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains {
            $0.contains("Log entry in Backwards Date Club is dated 2026-10-05, more than a day before 2026-10-10")
        })
        #expect(try store.organization("Backwards Date Club").logEntries.count == 2)

        // An entry without a date in between is skipped, so the comparison is with the entry above that one.
        #expect(spy.messages.contains {
            $0.contains("Log entry in Skipped Date Club is dated 2026-10-05, more than a day before 2026-10-10")
        })
    }

    @Test("A date that isn't written as YYYY-MM-DD stops a Debug build, and a Release build keeps the entry",
          .usesIfDebugFatalErrorSpy)
    func looseDateStopsDebug() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Illegal date value \"2026-2-3\"") })
        let entries = try store.organization("Loose Date Club").logEntries
        #expect(entries.count == 1)
        #expect(entries.first?.date_ == nil) // like any malformed date
    }

    // MARK: - Bad websites that break the rules

    @Test("A badWebsites that isn't an array stops a Debug build, and a Release build blocks nothing",
          .usesIfDebugFatalErrorSpy)
    func badWebsitesNotAnArrayStopsDebug() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("badWebsites in Bad Website List Club isn't a valid array") })
        #expect(try store.organization("Bad Website List Club").badWebsites_ == nil)
    }

    // A Release build stores every string as written, and drops what isn't a string, because it can't be stored.
    @Test("Each unusable entry in badWebsites stops a Debug build", .usesIfDebugFatalErrorSpy)
    func unusableBadWebsiteEntriesStopDebug() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await store.loadLevel1File(fileName: "logbookBadEntriesTest")
        #expect(spy.messages.contains { $0.contains("Bad Website Entries Club holds 42, which isn't a string") })
        #expect(spy.messages.contains { $0.contains("cannot parse") }) // "not a url", from URL.canonicalString
        let club = try store.organization("Bad Website Entries Club")
        #expect(club.badWebsites_ == "not a url\nhttps://www.fine.example.org")
    }

    // MARK: - A Level 2 file

    // Until Data#92, a Level 2 file can't supply these. Its other fields still load as usual.
    @Test("A logbook or badWebsites in a Level 2 file stops a Debug build, and a Release build ignores it",
          .usesIfDebugFatalErrorSpy)
    func level2LogbookKeysStopDebug() async throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        await Level2JsonReader.load(bgContext: store.makeBackgroundContext(),
                                    organizationIdPlus: OrganizationIdPlus(fullName: "Level 2 Keys Club",
                                                                           town: "Logtown",
                                                                           nickname: "logbookKeysTest"),
                                    isBeingTested: true,
                                    useOnlyInBundleFile: true)
        #expect(spy.messages.contains { $0.contains("Level 2 Keys Club has a logbook") })
        #expect(spy.messages.contains { $0.contains("Level 2 Keys Club has a badWebsites") })

        let club = try store.organization("Level 2 Keys Club")
        #expect(club.logEntries.isEmpty)
        #expect(club.badWebsites.isEmpty)
        #expect(club.organizationWebsite == URL(string: "https://www.level2-keys.example.org"))
    }

}
