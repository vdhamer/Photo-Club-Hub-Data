//
//  MergePolicyTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 05/08/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext, NSMergePolicy

// Data#12: the two consuming apps currently set _different_ merge policies on their background contexts —
// iOS uses mergeByPropertyStoreTrump, the HTML app mergeByPropertyObjectTrump —
// and the safety of the Level 0 completes and saves before Level 2 starts" invariant
// is claimed to depend on merge behaviour.
// Nobody had experimentally check which policy is actually correct, so these tests "measure" it.
//
// The collision under test: Level 0 creates an Expertise with `isSupported=true`, while Level 2's
// `findCreateUpdateUndefSupported()` passes `isSupported=nil`, which leaves a freshly inserted row at the
// Core Data default (false). If both contexts insert before either saves, the id_ uniqueness constraint
// has to resolve the duplicate at save time, and the merge policy decides which of both values survives.
//
// SCOPE: this characterises Core Data's conflict resolution *as this package depends on it*, not the
// package's own logic. It also does not reproduce a real race: both arms save in a fixed, explicit order,
// so the outcome is deterministic and this suite adds no flakiness of the kind described in Data#1.
// Note that when the sequencing works as intended no conflict arises at all — Level 2's fetch finds
// Level 0's committed row and takes the update path. What is measured here is the backstop behaviour
// for when the sequencing is absent or broken.
//
// The stakes are lower than the matrix below suggests, for a second reason. Within Level 2 the 14 club
// loaders run concurrently and two of them can interleave a read-then-create for the same new expertise
// — Core Data offers no serializable transaction, so that race is real — but they write *identical*
// rows, so the constraint deduplicates them and the policy has nothing to arbitrate. Only
// Level0JsonReader ever writes isSupported=true (via the single call to findCreateUpdateSupported);
// every Level 2 route reaches Expertise through Photographer.update with isSupported=nil and empty
// name/usage arrays; and Level1JsonReader never touches Expertise. Two clubs referencing the same
// expertise cannot disagree about it. So a wrong merge policy corrupts isSupported only when a Level 0
// and a Level 2 context collide, which the sequencing of "Level 0 before Level 2" prevents.
@MainActor
@Suite("Which merge policy protects Expertise.isSupported if Level 0 and Level 2 collide")
struct ExpertiseMergePolicyTests {

    private enum SaveOrder {
        case level0First // what the sequencing in Data#12 is meant to guarantee
        case level2First // only happens if the sequencing is absent or breaks
    }

    private struct Outcome {
        let isSupported: Bool?  // nil means the expertise did not survive at all
        let rowCount: Int       // 1 means the uniqueness constraint deduplicated as expected
        let saveError: String?  // non-nil means the conflict was not resolved by the policy
    }

    /// Runs one cell of the policy x save-order matrix (2x2).
    ///
    /// Both contexts call findCreateUpdate *before* either saves. Neither fetch can see the other's
    /// unsaved insert, so both genuinely insert and the collision is guaranteed rather than hoped for.
    private func collide(policy: NSMergePolicy, order: SaveOrder) -> Outcome {
        // A private in-memory store per call, so the cells of the matrix cannot see each other's records.
        let persistenceController = PersistenceController(inMemory: true)
        let expertiseID = String.random(length: 10)

        let level0Context = persistenceController.container.newBackgroundContext()
        let level2Context = persistenceController.container.newBackgroundContext()
        for context in [level0Context, level2Context] {
            context.mergePolicy = policy
        }

        _ = Expertise.findCreateUpdateSupported(context: level0Context, id: expertiseID,
                                                names: [], usages: []) // names & usages are for JSON input
        _ = Expertise.findCreateUpdateUndefSupported(context: level2Context, id: expertiseID,
                                                     name: [], usage: []) // names & usages are for JSON input

        // Save explicitly rather than via Expertise.save(): that helper discards the underlying error and
        // reports a fixed string via ifDebugFatalError. The IfDebugFatalErrorSpy seam could catch that, but it
        // is process-global (see Data#1) and exists for tests that deliberately trigger a guard and assert it
        // fired. Here a failed save is a "should never happen", so keeping the real NSError is more useful.
        let saveOrder = order == .level0First ? [level0Context, level2Context] : [level2Context, level0Context]
        var saveError: String?
        for context in saveOrder {
            // Return the message instead of mutating a captured var: performAndWait takes a @Sendable
            // closure, so writing to a captured `var` warns under strict concurrency even though the
            // closure runs synchronously and nothing escapes.
            let error: String? = context.performAndWait {
                guard context.hasChanges else { return nil }
                do {
                    try context.save()
                    return nil
                } catch {
                    context.rollback()
                    return "\(error)"
                }
            }
            saveError = saveError ?? error
        }

        // Read back through a third context so neither writer's in-memory state can mask the stored result.
        let readContext = persistenceController.container.newBackgroundContext()
        let (isSupported, rowCount): (Bool?, Int) = readContext.performAndWait {
            let fetchRequest: NSFetchRequest<Expertise> = Expertise.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id_ = %@",
                                                 argumentArray: [expertiseID.canonicalCase])
            let rows = (try? readContext.fetch(fetchRequest)) ?? []
            return (rows.first?.isSupported, rows.count)
        }

        return Outcome(isSupported: isSupported, rowCount: rowCount, saveError: saveError)
    }

    @Test("The id_ uniqueness constraint deduplicates the colliding inserts under either policy")
    func collisionLeavesExactlyOneRow() {
        for policy in [NSMergePolicy.mergeByPropertyStoreTrump, NSMergePolicy.mergeByPropertyObjectTrump] {
            for order in [SaveOrder.level0First, SaveOrder.level2First] {
                let outcome = collide(policy: policy, order: order)
                #expect(outcome.saveError == nil,
                        "conflicting save was not resolved by the merge policy: \(outcome.saveError ?? "")")
                #expect(outcome.rowCount == 1,
                        "expected the id_ constraint to leave 1 Expertise, found \(outcome.rowCount)")
            }
        }
    }

    @Test("StoreTrump keeps the value that was persisted first")
    func storeTrumpKeepsTheEarlierSave() {
        // Level 0 saved first, so its isSupported=true is the persisted value and must survive.
        #expect(collide(policy: .mergeByPropertyStoreTrump, order: .level0First).isSupported == true)
        // Level 2 saved first, so its false is the persisted value and Level 0 cannot promote it.
        #expect(collide(policy: .mergeByPropertyStoreTrump, order: .level2First).isSupported == false)
    }

    @Test("ObjectTrump keeps the value from the context that saved last")
    func objectTrumpKeepsTheLaterSave() {
        // Level 2 saved last, so its isSupported=false overwrites Level 0's true.
        #expect(collide(policy: .mergeByPropertyObjectTrump, order: .level0First).isSupported == false)
        // Level 0 saved last, so its true wins.
        #expect(collide(policy: .mergeByPropertyObjectTrump, order: .level2First).isSupported == true)
    }

    @Test("Neither policy is safe on its own: each protects only one save order")
    func neitherPolicyIsSafeWithoutSequencing() {
        // The point of the matrix, stated as one assertion. Whichever policy is chosen, there is a save
        // order that corrupts isSupported — so the ordering guarantee, not the merge policy, is what
        // actually protects the flag. The policy only decides which way an unsequenced load fails.
        let storeTrumpSafeOrders = [SaveOrder.level0First, .level2First]
            .filter { collide(policy: .mergeByPropertyStoreTrump, order: $0).isSupported == true }
        let objectTrumpSafeOrders = [SaveOrder.level0First, .level2First]
            .filter { collide(policy: .mergeByPropertyObjectTrump, order: $0).isSupported == true }

        #expect(storeTrumpSafeOrders.count == 1, "StoreTrump unexpectedly survived both save orders")
        #expect(objectTrumpSafeOrders.count == 1, "ObjectTrump unexpectedly survived both save orders")
    }
}

// What the merge policy means for ordinary club data, as opposed to the Expertise suite above.
//
// The two suites cover different situations. In the Expertise case one of the two colliding values is
// simply wrong, so the policy decides correctness. Here both values are legitimate: a photographer who
// belongs to two clubs is loaded by two Level 2 loaders running concurrently, each carrying its own
// club's view of that person, and the row already exists so the second save hits an optimistic-locking
// conflict rather than a uniqueness collision.
//
// The standing property this documents: **one club's data silently wins, and which one depends on the
// merge policy** — StoreTrump keeps the club that saved first, ObjectTrump the club that saved last.
// Neither is more correct and neither is fresher, since both loaders read same-vintage JSON within one
// pass. So this is the answer to "why did this photographer's birth date change?", and after Data#12 —
// where the package sets the merge policy instead of each app — it is the specification of what that
// choice means in practice. Two clubs publishing different data about one person is a data problem, not
// something a merge policy can fix.
@MainActor
@Suite("Which merge policy wins when two club loaders update the same photographer")
struct PhotographerMergePolicyTests {

    private struct Outcome {
        let bornDT: Date?      // whichever club's value survived
        let saveError: String? // non-nil means the conflict was not resolved by the policy
    }

    private let clubADate = Date(timeIntervalSince1970: 1_000_000)
    private let clubBDate = Date(timeIntervalSince1970: 2_000_000)
    private let seedDate = Date(timeIntervalSince1970: 0)

    /// Seeds a photographer, then has two contexts update the same property to different values before
    /// either saves, so the second save hits a genuine optimistic-locking conflict.
    private func concurrentUpdate(policy: NSMergePolicy) -> Outcome {
        let persistenceController = PersistenceController(inMemory: true)
        let personName = PersonName(givenName: String.random(length: 10),
                                    infixName: "",
                                    familyName: "UnitTestDummy")

        // Seed the row and commit it, so both club contexts start from the same stored snapshot.
        let seedContext = persistenceController.container.newBackgroundContext()
        seedContext.mergePolicy = policy
        _ = Photographer.findCreateUpdate(context: seedContext, personName: personName,
                                          optionalFields: PhotographerOptionalFields(bornDT: seedDate))
        seedContext.performAndWait { try? seedContext.save() }

        let clubAContext = persistenceController.container.newBackgroundContext()
        let clubBContext = persistenceController.container.newBackgroundContext()
        for context in [clubAContext, clubBContext] {
            context.mergePolicy = policy
        }

        // Both fetch the seeded row and change the same property, neither having saved yet.
        _ = Photographer.findCreateUpdate(context: clubAContext, personName: personName,
                                          optionalFields: PhotographerOptionalFields(bornDT: clubADate))
        _ = Photographer.findCreateUpdate(context: clubBContext, personName: personName,
                                          optionalFields: PhotographerOptionalFields(bornDT: clubBDate))

        var saveError: String?
        for context in [clubAContext, clubBContext] { // club A saves first, so club B's save conflicts
            let error: String? = context.performAndWait { // returned rather than captured, as above
                guard context.hasChanges else { return nil }
                do {
                    try context.save()
                    return nil
                } catch {
                    context.rollback()
                    return "\(error)"
                }
            }
            saveError = saveError ?? error
        }

        let readContext = persistenceController.container.newBackgroundContext()
        let givenName = personName.givenName // hoisted out: PersonName is not Sendable, String is
        let bornDT: Date? = readContext.performAndWait {
            let fetchRequest: NSFetchRequest<Photographer> = Photographer.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "givenName_ = %@",
                                                 argumentArray: [givenName])
            return (try? readContext.fetch(fetchRequest))?.first?.bornDT
        }

        return Outcome(bornDT: bornDT, saveError: saveError)
    }

    @Test("StoreTrump keeps the first club's value and discards the second club's")
    func storeTrumpDiscardsTheSecondLoader() {
        let outcome = concurrentUpdate(policy: .mergeByPropertyStoreTrump)
        #expect(outcome.saveError == nil, "conflicting save was not resolved: \(outcome.saveError ?? "")")
        #expect(outcome.bornDT == clubADate)
    }

    @Test("ObjectTrump keeps the second club's value and discards the first club's")
    func objectTrumpDiscardsTheFirstLoader() {
        let outcome = concurrentUpdate(policy: .mergeByPropertyObjectTrump)
        #expect(outcome.saveError == nil, "conflicting save was not resolved: \(outcome.saveError ?? "")")
        #expect(outcome.bornDT == clubBDate)
    }

    @Test("Neither policy loses data the other keeps: they differ only in which club wins")
    func bothPoliciesKeepExactlyOneClubsValue() {
        // For legitimate concurrent updates the two policies are equally lossy: exactly one club's value
        // survives either way. So switching policy cannot recover data — it only moves which club wins.
        // Anyone reaching for a policy change to fix a disagreement between two clubs is at the wrong
        // layer; the fix is in the JSON.
        let storeTrumpValue = concurrentUpdate(policy: .mergeByPropertyStoreTrump).bornDT
        let objectTrumpValue = concurrentUpdate(policy: .mergeByPropertyObjectTrump).bornDT

        #expect([clubADate, clubBDate].contains(storeTrumpValue))
        #expect([clubADate, clubBDate].contains(objectTrumpValue))
        #expect(storeTrumpValue != objectTrumpValue, "the policies were expected to pick different winners")
    }
}
