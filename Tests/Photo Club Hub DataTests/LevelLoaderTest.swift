//
//  LevelLoaderTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 06/08/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext, NSPersistentContainer
import Foundation // for NSLock, NotificationCenter

// Data#12: "Level 0 must complete and save before Level 2 starts" was formerly implemented in the
// consuming apps and tested by neither. Now that LevelLoader owns the sequencing, this asserts it.
//
// The assertion is on *save order*, not on start order, because saving is what the invariant is about:
// the Expertise uniqueness constraint on id_ only resolves a collision when two contexts both `save()`.
// Observing NSManagedObjectContextDidSave gives that directly, without resorting to sleeps or polling.
//
// `.serialized` is load-bearing, not tidiness: the first test observes NSManagedObjectContextDidSave,
// which is a process-global notification stream. It filters on its own store's coordinator, so a
// concurrent pass cannot corrupt what it records — but serializing keeps the recorded order easy to
// reason about when a failure has to be diagnosed from the message alone.
// The visited-file guard needs no such care any more: each pass owns its own Level1History.
@MainActor
@Suite("LevelLoader sequences the levels", .serialized)
struct LevelLoaderTests {

    /// Records the names of contexts that saved, in the order the saves committed.
    ///
    /// Saves commit on the background contexts' own queues, so recording needs a lock.
    /// NSLock rather than Mutex to match the rest of the package, which still supports iOS 17.
    private final class SaveOrderRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var names: [String] = []

        func record(_ name: String) {
            lock.lock()
            defer { lock.unlock() }
            names.append(name)
        }

        var recorded: [String] {
            lock.lock()
            defer { lock.unlock() }
            return names
        }
    }

    @Test("Level 0 saves before any Level 2 loader saves")
    func level0SavesBeforeLevel2() async {
        // A private in-memory store, so this suite neither sees nor disturbs the app's store or other tests.
        let persistenceController = PersistenceController(inMemory: true)
        let coordinator = persistenceController.container.persistentStoreCoordinator

        let recorder = SaveOrderRecorder()
        // Filtering on the coordinator matters: NSManagedObjectContextDidSave is process-global, and
        // Swift Testing runs suites in parallel, so an unfiltered observer would also record saves made
        // by unrelated tests (the flakiness described in Data#1).
        let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave,
                                                             object: nil,
                                                             queue: nil) { notification in
            guard let context = notification.object as? NSManagedObjectContext,
                  context.persistentStoreCoordinator === coordinator,
                  let name = context.name else { return }
            recorder.record(name)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await LevelLoader.loadAllLevels(usedContainer: persistenceController.container,
                                        isBeingTested: true,
                                        useOnlyInBundleFile: true) // no network: use the bundled JSON files

        let saveOrder = recorder.recorded
        let level0Index = saveOrder.firstIndex(of: "Level 0 loader")
        let firstLevel2Index = saveOrder.firstIndex { $0.hasPrefix("Level 2 loader") }

        #expect(level0Index != nil, "Level 0 never saved; save order was \(saveOrder)")
        #expect(firstLevel2Index != nil, "No Level 2 loader saved; save order was \(saveOrder)")

        if let level0Index, let firstLevel2Index {
            #expect(level0Index < firstLevel2Index,
                    "Level 0 must save before any Level 2 loader; save order was \(saveOrder)")
        }
    }

    @Test("Every expertise Level 0 declares is still supported after a full load pass")
    func level0ExpertisesStaySupported() async {
        // The consequence of the ordering, checked on the data rather than on the schedule.
        // The baseline is derived from a Level-0-only load rather than hard-coded, so the assertion keeps
        // its meaning when root.level0.json gains or loses an expertise.
        let baselineController = PersistenceController(inMemory: true)
        await Level0JsonReader.load(
            bgContext: LevelLoader.makeBgContext(ctxName: "Level 0 loader",
                                                 usedContainer: baselineController.container),
            isBeingTested: true,
            useOnlyInBundleFile: true)
        let declaredIDs = supportedExpertiseIDs(in: baselineController)
        #expect(declaredIDs.isEmpty == false, "Level 0 declared no supported expertises at all")

        let fullPassController = PersistenceController(inMemory: true)
        await LevelLoader.loadAllLevels(usedContainer: fullPassController.container,
                                        isBeingTested: true,
                                        useOnlyInBundleFile: true)
        let survivingIDs = supportedExpertiseIDs(in: fullPassController)

        // Expertises that only Level 2 references are legitimately unsupported ("temporary"), so the
        // assertion is one-directional: nothing Level 0 declared may have been downgraded.
        let downgraded = declaredIDs.subtracting(survivingIDs)
        #expect(downgraded.isEmpty,
                "Level 2 downgraded these Level 0 expertises to temporary: \(downgraded.sorted())")
    }

    @Test("Two load passes in one process do not trip the visited-file guard")
    func secondPassIsNotADuplicate() async {
        // The visited-file guard used to be a process-global singleton, so a second pass without an
        // intervening Model.deleteCoreDataObjects reported every Level 1 file as an infinite loop or
        // duplicate. Each pass now owns its Level1History, which is what this pins down.
        //
        // The spy is what makes the assertion possible at all: without it the guard's ifDebugFatalError
        // would abort the whole test run in a DEBUG build rather than fail this one test.
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        let persistenceController = PersistenceController(inMemory: true)
        for pass in 1...2 {
            await LevelLoader.loadAllLevels(usedContainer: persistenceController.container,
                                            isBeingTested: true,
                                            useOnlyInBundleFile: true)
            #expect(spy.messages.isEmpty, "Pass \(pass) reported: \(spy.messages)")
        }
    }

    private func supportedExpertiseIDs(in controller: PersistenceController) -> Set<String> {
        let request = NSFetchRequest<Expertise>(entityName: "Expertise")
        let expertises = (try? controller.container.viewContext.fetch(request)) ?? []
        return Set(expertises.filter { $0.isSupported }.map { $0.id })
    }
}
