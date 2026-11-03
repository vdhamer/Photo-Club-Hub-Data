//
//  PhotographerContentionTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 28/08/2026.
//

import Testing
import Foundation // for Date
import CoreData // for NSManagedObjectContext, NSMergePolicy
@testable import Photo_Club_Hub_Data // for Photographer, PersonName, PhotographerOptionalFields

// Level 2 files describe one club each, so the concurrent loaders normally fill disjoint sets of rows.
// The exception is any photographer who is a member of two clubs: `Photographer` is constrained on
// (familyName_, infixName_, givenName_), so both files reference the same row in the `Photographer` table.
// That row contains that person's club-independent properties, like a single-value (optional) birthday.
//
// `Photographer.update()` merges such a row into the database field by field - nil never overwrites,
// a differing non-nil does.
// Those rules are ordinary Swift Core Data, so they only run in a context that can already see the row.
// These tests pin where that holds and where it stops:
//
// - once the row is committed, every loader fetches it, nobody inserts a second one, and no merge policy is
//   consulted. A value already in the store is then safe, which is the guarantee that matters: a Level 2
//   file that happens to omit a birthday must never turn a known birthday back into "unknown".
// - before the row exists - a first load (or a load after a wipe) two loaders can both try to create it, and the
//   uniqueness constraint is settled in the store by save order rather than by the field rules.
//
// Nothing pre-creates photographers, the way LevelLoader awaits Level 0 for Expertise and initConstants()
// pre-creates the contended Language and OrganizationType rows. See MergePolicyTest for the same mechanism
// on Expertise, and Data#22 §1.5 A3.
@Suite("What happens when two Level 2 clubs describe the same photographer")
struct PhotographerContentionTests {

    private struct Outcome {
        let bornDT: Date?      // the birthday that ended up in the store
        let rowCount: Int      // 1 means the uniqueness constraint deduplicated as expected
        let saveError: String? // non-nil means the conflict was not resolved by the policy
    }

    private static let knownBirthday = Date(timeIntervalSince1970: 123_456)
    private static let otherBirthday = Date(timeIntervalSince1970: 923_456)

    // All arguments are passed explicitly: the default arguments of PhotographerOptionalFields.init
    // reference SwiftyJSON.JSON, and default arguments are emitted in the caller, so relying on them
    // would require the test target to link SwiftyJSON too.
    private func optionalFields(bornDT: Date?) -> PhotographerOptionalFields {
        PhotographerOptionalFields(bornDT: bornDT,
                                   isDeceased: nil,
                                   photographerWebsite: nil,
                                   photographerImage: nil,
                                   photographerExpertises: [])
    }

    private func makeContext(in controller: PersistenceController) -> NSManagedObjectContext {
        let context = controller.container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump // the policy LevelLoader configures
        return context
    }

    // Returns the underlying error rather than going through Photographer.save(), which reports a fixed
    // string via ifDebugFatalError. Here a failed save is a "should never happen", so the real one is useful.
    @discardableResult private func save(_ context: NSManagedObjectContext) -> String? {
        context.performAndWait {
            guard context.hasChanges else { return nil }
            do {
                try context.save()
                return nil
            } catch {
                context.rollback()
                return "\(error)"
            }
        }
    }

    private func readBirthday(named personName: PersonName,
                              from controller: PersistenceController) -> (bornDT: Date?, rowCount: Int) {
        // Read through a context of its own so neither writer's in-memory state can mask the stored result.
        let familyName: String = personName.familyName // capture a Sendable value, not the PersonName
        let readContext = controller.container.newBackgroundContext()
        return readContext.performAndWait {
            let fetchRequest: NSFetchRequest<Photographer> = Photographer.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "familyName_ = %@", familyName)
            let rows = (try? readContext.fetch(fetchRequest)) ?? []
            return (rows.first?.bornDT, rows.count)
        }
    }

    private func randomPersonName() -> PersonName {
        PersonName(givenName: "John", infixName: "", familyName: "Doe\(String.random(length: 10))")
    }

    /// Seeds one committed photographer, then runs two loaders that never see each other's unsaved work.
    private func twoLoadersAfterSeeding(with incoming: Date?) -> Outcome {
        let controller = PersistenceController(inMemory: true)
        let personName = randomPersonName()

        let seedContext = makeContext(in: controller)
        _ = Photographer.findCreateUpdate(context: seedContext, personName: personName,
                                          optionalFields: optionalFields(bornDT: Self.knownBirthday))
        save(seedContext)

        let firstContext = makeContext(in: controller)
        let secondContext = makeContext(in: controller)
        _ = Photographer.findCreateUpdate(context: firstContext, personName: personName,
                                          optionalFields: optionalFields(bornDT: incoming))
        _ = Photographer.findCreateUpdate(context: secondContext, personName: personName,
                                          optionalFields: optionalFields(bornDT: incoming))
        // Save both regardless: `??` would skip the second save whenever the first one failed.
        let firstError = save(firstContext)
        let secondError = save(secondContext)
        let error = firstError ?? secondError

        let result = readBirthday(named: personName, from: controller)
        return Outcome(bornDT: result.bornDT, rowCount: result.rowCount, saveError: error)
    }

    @Test("A birthday already in the store survives two clubs that do not mention one")
    func storedBirthdayIsNotErasedByFilesThatOmitIt() {
        let outcome = twoLoadersAfterSeeding(with: nil)
        #expect(outcome.saveError == nil, "save failed: \(outcome.saveError ?? "")")
        #expect(outcome.rowCount == 1, "expected 1 Photographer, found \(outcome.rowCount)")
        #expect(outcome.bornDT == Self.knownBirthday,
                "a Level 2 file without a birthday turned a known birthday back into unknown")
    }

    @Test("A club that supplies a different birthday overwrites the stored one")
    func differingBirthdayWins() {
        let outcome = twoLoadersAfterSeeding(with: Self.otherBirthday)
        #expect(outcome.saveError == nil, "save failed: \(outcome.saveError ?? "")")
        #expect(outcome.rowCount == 1, "expected 1 Photographer, found \(outcome.rowCount)")
        // There is no basis for preferring the stored value, so last writer wins is the intended outcome.
        #expect(outcome.bornDT == Self.otherBirthday)
    }

    /// Both loaders create the photographer before either saves, so neither fetch can see the other's
    /// insert and the collision is guaranteed rather than hoped for.
    private func concurrentCreation(nilLoaderSavesFirst: Bool) -> Outcome {
        let controller = PersistenceController(inMemory: true)
        let personName = randomPersonName()

        let datedContext = makeContext(in: controller)
        let emptyContext = makeContext(in: controller)
        _ = Photographer.findCreateUpdate(context: datedContext, personName: personName,
                                          optionalFields: optionalFields(bornDT: Self.knownBirthday))
        _ = Photographer.findCreateUpdate(context: emptyContext, personName: personName,
                                          optionalFields: optionalFields(bornDT: nil))

        let saveOrder = nilLoaderSavesFirst ? [emptyContext, datedContext] : [datedContext, emptyContext]
        var error: String?
        for context in saveOrder {
            error = error ?? save(context)
        }

        let result = readBirthday(named: personName, from: controller)
        return Outcome(bornDT: result.bornDT, rowCount: result.rowCount, saveError: error)
    }

    @Test("Colliding creates leave exactly one photographer under either save order")
    func collisionLeavesExactlyOnePhotographer() {
        for nilFirst in [true, false] {
            let outcome = concurrentCreation(nilLoaderSavesFirst: nilFirst)
            #expect(outcome.saveError == nil, "conflicting save was not resolved: \(outcome.saveError ?? "")")
            #expect(outcome.rowCount == 1, "expected 1 Photographer, found \(outcome.rowCount)")
        }
    }

    @Test("When the row is created twice, save order decides the birthday, not the field rules")
    func concurrentCreateIsSettledBySaveOrder() {
        // The field rules would keep the birthday in both arms. They do not run here: the row is inserted
        // twice, and StoreTrump keeps whichever version reached the store first - nil included. This costs
        // an offered value rather than a stored one, and the next load pass acquires it, because by then
        // the row exists and Photographer.update() does run.
        #expect(concurrentCreation(nilLoaderSavesFirst: true).bornDT == nil)
        #expect(concurrentCreation(nilLoaderSavesFirst: false).bornDT == Self.knownBirthday)
    }
}
