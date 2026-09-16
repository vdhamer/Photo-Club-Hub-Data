//
//  SupportedLanguagesTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code under guidance of Peter van den Hamer on 16/09/2026.
//
//  Covers Language.isSupported: how Level 0 sets it, and which other paths must leave it alone (Data#57).
//  The fixtures carry the cases: rootTest flags EN and NL (DE has no key), languagesTest.level0.json lists EN
//  without the key, and languageTest.level0.json lists neither EN nor NL.
//

import Testing // for macros like `expect`
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

@MainActor @Suite("Tests which languages count as supported languages") struct SupportedLanguagesTests {

    private let testPersistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext

    init () {
        // A private in-memory store per test, like the other suites: the shared coordinator would let
        // parallel suites pollute each other's Language rows. See issue #756.
        testPersistenceController = PersistenceController(inMemory: true)
        viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // Level 0 must be awaited rather than constructed: `init` hands the work to bgContext.perform { } and
    // returns before parsing, so an assertion right after it would race the loader (see Level0JsonReader).
    private func loadTestLevel0(fileName: String = "rootTest") async {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = "Level 0 loader for \(fileName)"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true

        await Level0JsonReader.load(bgContext: bgContext,
                                    fileName: fileName,
                                    isBeingTested: false,
                                    useOnlyInBundleFile: true)
    }

    private func supportedIsoCodes() -> [String] {
        Language.supportedLanguages(context: viewContext).map { $0.isoCode }
    }

    // MARK: - what Level 0 declares

    // rootTest.level0.json annotates EN and NL as supported, and DE does not have that annotation.
    @Test("Distinguish supported and unsupported languages in the Level 0 data") func flaggedLanguages() async {
        await loadTestLevel0()

        #expect(supportedIsoCodes() == ["en", "nl"]) // sorted by ISO code
        #expect(Language.find(context: viewContext, isoCode: "de")?.isSupported == false)
    }

    // Before any Level 0 file is read, nothing is supported: the attribute defaults to false.
    @Test("Nothing is supported before Level 0 has been read") func emptyBeforeLevel0() {
        Language.initConstants(context: viewContext) // creates six languages, none of them flagged

        #expect(supportedIsoCodes().isEmpty)
    }

    // MARK: - what a later load does

    // Only an explicit false withdraws support: languageWithdrawnTest.level0.json says so for EN.
    @Test("An explicit false withdraws support") func explicitFalseWithdraws() async {
        await loadTestLevel0()
        #expect(supportedIsoCodes().contains("en"))

        await loadTestLevel0(fileName: "languageWithdrawnTest")

        #expect(supportedIsoCodes() == ["nl"]) // EN withdrawn; NL carries no key there, so it is untouched
    }

    // languagesTest.level0.json lists EN without the key. Absent means "no opinion", as for the role booleans
    // in a Level 2 file: only an explicit value changes a stored flag, so EN stays supported.
    @Test("A listed language without the key keeps its flag") func keyAbsentKeepsFlag() async {
        await loadTestLevel0()

        await loadTestLevel0(fileName: "languagesTest")

        #expect(supportedIsoCodes() == ["en", "nl"])
    }

    // languageTest.level0.json lists only UR, so EN and NL are absent from it. Loads only merge: absent records
    // are not touched, so both keep their flag until the store is reset (Data#39).
    @Test("A language missing during a later load keeps its flag") func languageNoLongerListed() async {
        await loadTestLevel0()

        await loadTestLevel0(fileName: "languageTest") // lists UR three times, and neither EN nor NL

        #expect(supportedIsoCodes() == ["en", "nl"])
    }

    // MARK: - What the other creators of Language rows must not do

    // initConstants seeds six languages and passes no flag, so it may neither grant nor withdraw support.
    @Test("initConstants leaves an existing flag alone") func initConstantsKeepsFlag() async {
        await loadTestLevel0()

        Language.initConstants(context: viewContext) // "en" and "nl" are among the six it seeds

        #expect(supportedIsoCodes() == ["en", "nl"])
    }

    // A remark or an expertise translation reaches findCreateUpdate without a flag: nil means "leave it".
    @Test("creating a language for a remark grants no support and changes no flag") func remarkLanguage() async {
        await loadTestLevel0()

        // "pdc" (Pennsylvania Dutch) stands in for the language of a Level 1 remark: a new row.
        let remarkLanguage = Language.findCreateUpdate(context: viewContext, isoCode: "pdc")
        // The same call shape reaching a language that Level 0 did flag must not withdraw that flag.
        let existingLanguage = Language.findCreateUpdate(context: viewContext, isoCode: "en")

        #expect(remarkLanguage.isSupported == false)
        #expect(existingLanguage.isSupported == true)
        #expect(supportedIsoCodes() == ["en", "nl"])
    }
}
