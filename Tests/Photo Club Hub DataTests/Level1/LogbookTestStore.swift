//
//  LogbookTestStore.swift
//  Photo Club HubTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 03/11/2026.
//

@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

// The in-memory store and helpers shared by the test suites for the logbook and bad websites (Data#91).
// Each suite creates its own instance per test, so every test starts from an empty store.
@MainActor struct LogbookTestStore {

    let persistenceController: PersistenceController
    let viewContext: NSManagedObjectContext

    init () {
        persistenceController = PersistenceController(inMemory: true) // inMemory is important for isolation
        viewContext = persistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // The empty store lacks the constant records the app prefills at launch; so we insert them here.
        Language.initConstants(context: viewContext) // e.g. NL
        OrganizationType.initConstants(context: viewContext) // e.g. club
    }

    func makeBackgroundContext() -> NSManagedObjectContext {
        let bgContext = persistenceController.container.newBackgroundContext()
        bgContext.name = "LogbookTestStore"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true
        return bgContext
    }

    func loadLevel1File(fileName: String) async {
        await Level1JsonReader.load(bgContext: makeBackgroundContext(),
                                    fileName: fileName,
                                    isBeingTested: true,
                                    useOnlyInBundleFile: true,
                                    usedContainer: persistenceController.container)
    }

    // Refreshes first, because the load changed the store through another context.
    func organization(_ fullName: String) throws -> Organization {
        viewContext.refreshAllObjects()
        return try Organization.find(context: viewContext,
                                     organizationID: OrganizationID(fullName: fullName, town: "Logtown"))
    }

    func allLogEntries() -> [LogEntry] {
        (try? viewContext.fetch(LogEntry.fetchRequest())) ?? []
    }

}
