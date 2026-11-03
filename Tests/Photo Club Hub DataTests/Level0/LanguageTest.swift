//
//  LanguageTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 29/06/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

@MainActor @Suite("Tests the Core Data Language class") struct LanguageTests {

    private let testPersistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext

    init () {
        // Use a private in-memory store rather than PersistenceController.shared. Sharing the singleton
        // coordinator across parallel suites deadlocks (main-queue performAndWait fetches contending with
        // background-context saves) and lets suites pollute each other's records. See issue #756.
        testPersistenceController = PersistenceController(inMemory: true)
        viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // Calling findCreateUpdate twice with the same ISO code must return the same object (no duplicate).
    @Test("findCreateUpdate is idempotent for a given ISO code") func idempotentForSameCode() {
        let isoCode = "qx" + String.random(length: 6) // "qx" guarantees the code contains letters

        let language1 = Language.findCreateUpdate(context: viewContext, isoCode: isoCode)
        let language2 = Language.findCreateUpdate(context: viewContext, isoCode: isoCode)

        #expect(language1 === language2) // same managed object, not a second copy
        #expect(Language.count(context: viewContext, isoCode: isoCode) == 1) // exactly one record for this code
    }

    // The documented contract is that ISO codes are matched case-insensitively.
    // Note this exercises only the *argument* being uppercase; findCreateUpdate lowercases it before
    // querying, so this passes even with an exact-match predicate. For an uppercase value already in
    // the store, see matchesLegacyUppercaseRow() below.
    @Test("ISO code is matched case-insensitively") func languageIDMatchedCaseInsensitively() {
        let isoCode = "qx" + String.random(length: 6) // "qx" guarantees lower/upper actually differ

        let lower = Language.findCreateUpdate(context: viewContext, isoCode: isoCode.lowercased())
        let upper = Language.findCreateUpdate(context: viewContext, isoCode: isoCode.uppercased())

        #expect(lower === upper) // both resolve to the same object
        #expect(lower.isoCode == isoCode.lowercased()) // stored code is normalized to lowercase
        #expect(Language.count(context: viewContext, isoCode: isoCode) == 1) // still only one record
    }

    // Shipping versions stored uppercase ISO codes, so an upgraded store can hold values the current
    // normalizing setter could never produce. Write isoCode_ directly to reproduce that state: an
    // exact-match predicate misses the row and findCreateUpdate silently creates a duplicate.
    @Test("findCreateUpdate matches a legacy uppercase row already in the store")
    func matchesLegacyUppercaseRow() {
        let isoCode = "qx" + String.random(length: 6) // "qx" guarantees lower/upper actually differ

        let entity = NSEntityDescription.entity(forEntityName: "Language", in: viewContext)!
        let legacy = Language(entity: entity, insertInto: viewContext)
        legacy.isoCode_ = isoCode.uppercased() // bypasses the normalizing isoCode setter on purpose
        try? viewContext.save()

        let found = Language.findCreateUpdate(context: viewContext, isoCode: isoCode.lowercased())

        #expect(found === legacy) // the legacy row is reused, not shadowed by a second one
        #expect(Language.count(context: viewContext, isoCode: isoCode) == 1) // no duplicate created
        #expect(found.isoCode == isoCode.lowercased()) // the getter self-heals the stored value
    }

    // nil update semantics: nameENOptional == nil must leave an already-set name untouched.
    @Test("nil nameENOptional does not overwrite an existing name") func nilNameDoesNotOverwrite() {
        let isoCode = "qx" + String.random(length: 6)

        let language1 = Language.findCreateUpdate(context: viewContext, isoCode: isoCode, nameENOptional: "Klingon")
        #expect(language1.nameEN == "Klingon")

        let language2 = Language.findCreateUpdate(context: viewContext, isoCode: isoCode, nameENOptional: nil)
        #expect(language2 === language1) // same object
        #expect(language2.nameEN == "Klingon") // unchanged by the nil call
    }

}
