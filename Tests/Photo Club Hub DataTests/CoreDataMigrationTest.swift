//
//  CoreDataMigrationTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 03/11/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSPersistentStoreCoordinator

// A store written with an older model must open with the current one. Core Data then converts it in place,
// working out the mapping by itself (a "lightweight" migration). If it can't, an app stops at launch, because
// PersistenceController treats a store that fails to load as fatal. So each new model version is checked here
// against the versions that released apps use.
@MainActor @Suite("Migrates stores from released model versions to the current one") struct CoreDataMigrationTests {

    @Test("A store from an older model opens with the current model, and keeps its data",
          arguments: ["Photo_Club_Hub_3_9_0", // used by the HTML app and iOS 3.0.5 development builds (Data 3.9.0)
                      "Photo_Club_Hub_3_8_0", // used by app builds that resolve Data 3.8.0
                      "Photo_Club_Hub_3_7_0", // used by iOS 3.0.3 and 3.0.4 (Data 3.7.0 to 3.7.2)
                      "Photo_Club_Hub_3_5_0"]) // used by iOS 3.0.2 (Data 3.5.0)
    func storeMigratesToCurrentModel(oldVersion: String) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MigrationTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Photo_Club_Hub.sqlite")

        try writeStore(at: storeURL, with: try oldModel(oldVersion))

        let context = try openStore(at: storeURL, with: PersistenceController.model) // migrates
        let organizations: [Organization] = try context.fetch(Organization.fetchRequest())
        #expect(organizations.map(\.fullName) == ["Migrated Club"])
        let club = try #require(organizations.first)
        #expect(club.town == "Oldtown")
        #expect(club.nickName == "migratedClub")

        // Renamed in 3_9_0 (removeOrganization and removeMember became obsolete): the stored value carries over.
        // In a 3_9_0 store they already have the new name.
        #expect(club.obsolete == true)
        let memberships: [MemberPortfolio] = try context.fetch(MemberPortfolio.fetchRequest())
        #expect(memberships.map(\.obsolete) == [true])

        // status_ is new in 3_10_0 (Data#116). The type changed from Bool, so a stored isFormerOrganization isn't
        // carried over: every organization is active until the next Level 1 load sets its status. The old store
        // has the club as former wherever the old model can say so, so this also shows that the old value is dropped.
        #expect(club.status_ == "active")
        // A log entry from 3_8_0 or 3_9_0 keeps its row and text, and loses its isFormerOrganization_.
        let oldModelHasLog: Bool = ["Photo_Club_Hub_3_8_0", "Photo_Club_Hub_3_9_0"].contains(oldVersion)
        #expect(club.logEntries.map(\.text) == (oldModelHasLog ? ["Written before the migration."] : []))
        #expect(club.logEntries.allSatisfy { $0.status_ == nil })

        // The attributes that the old model lacked, with their defaults.
        #expect(club.badWebsites_ == nil)
        let expertises: [Expertise] = try context.fetch(Expertise.fetchRequest())
        #expect(expertises.map(\.id_) == ["migratedExpertise"])
        #expect(expertises.first?.obsolete == false)
        let photographers: [Photographer] = try context.fetch(Photographer.fetchRequest())
        #expect(photographers.map(\.obsolete) == [false])

        // The new entity works in the migrated store.
        let entity = try #require(NSEntityDescription.entity(forEntityName: "LogEntry", in: context))
        let logEntry = LogEntry(entity: entity, insertInto: context)
        logEntry.organization_ = club
        logEntry.text_ = "Written after the migration."
        logEntry.position = 1 // after the migrated entry, if any: organization, level and position are unique
        try context.save()
        #expect(club.logEntries.count == (oldModelHasLog ? 2 : 1))
        #expect(club.logEntries.allSatisfy { $0.originalDataSourceLevel == 1 })

        // From 3_9_0, deleting an organization also deletes its cached addresses (delete rule Cascade, for Data#39).
        #expect(try context.count(for: LocalizedAddress.fetchRequest()) == 1)
        context.delete(club)
        try context.save()
        #expect(try context.count(for: LocalizedAddress.fetchRequest()) == 0)
    }

    // One of the older versions inside the compiled model, which keeps every version.
    private func oldModel(_ version: String) throws -> NSManagedObjectModel {
        let modelURL = try #require(Bundle.photoClubHubDataModule.url(forResource: "Photo_Club_Hub",
                                                                      withExtension: "momd"))
        let model = try #require(NSManagedObjectModel(contentsOf: modelURL.appending(path: "\(version).mom")))
        // Plain NSManagedObject, so that this second model doesn't also claim classes such as Organization.
        // Two models claiming one class confuse Core Data (see PersistenceController.model).
        for entity in model.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        return model
    }

    // Writes one club with the old model, then closes the store, as an older app version would leave it.
    // Attributes that only some old models have are set only where the model has them.
    private func writeStore(at url: URL, with model: NSManagedObjectModel) throws {
        let context = try openStore(at: url, with: model)
        let club = NSEntityDescription.insertNewObject(forEntityName: "Organization", into: context)
        club.setValue("Migrated Club", forKey: "fullName_")
        club.setValue("Oldtown", forKey: "town_")
        club.setValue("migratedClub", forKey: "nickName_")
        setFirstAttribute(of: club, from: ["removeOrganization", "obsolete"], to: true) // renamed in 3_9_0
        setFirstAttribute(of: club, from: ["isFormerOrganization"], to: true) // 3_8_0 and 3_9_0 only
        if model.entitiesByName["LogEntry"]?.attributesByName["isFormerOrganization_"] != nil { // 3_8_0 and 3_9_0
            let logEntry = NSEntityDescription.insertNewObject(forEntityName: "LogEntry", into: context)
            logEntry.setValue(club, forKey: "organization_")
            logEntry.setValue("Written before the migration.", forKey: "text_")
            logEntry.setValue(true, forKey: "isFormerOrganization_")
        }
        let membership = NSEntityDescription.insertNewObject(forEntityName: "MemberPortfolio", into: context)
        membership.setValue(club, forKey: "organization_")
        setFirstAttribute(of: membership, from: ["removeMember", "obsolete"], to: true) // renamed in 3_9_0
        let photographer = NSEntityDescription.insertNewObject(forEntityName: "Photographer", into: context)
        membership.setValue(photographer, forKey: "photographer_")
        let address = NSEntityDescription.insertNewObject(forEntityName: "LocalizedAddress", into: context)
        address.setValue(club, forKey: "organization_")
        let expertise = NSEntityDescription.insertNewObject(forEntityName: "Expertise", into: context)
        expertise.setValue("migratedExpertise", forKey: "id_")
        try context.save()

        let coordinator = try #require(context.persistentStoreCoordinator)
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    // Sets the first of these attributes that the object's entity has, if any.
    private func setFirstAttribute(of object: NSManagedObject, from keys: [String], to value: Bool) {
        if let key = keys.first(where: { object.entity.attributesByName[$0] != nil }) {
            object.setValue(value, forKey: key)
        }
    }

    // Opened the way PersistenceController opens the apps' store: SQLite with persistent history tracking,
    // and NSPersistentContainer's defaults, which migrate automatically and infer the mapping.
    private func openStore(at url: URL, with model: NSManagedObjectModel) throws -> NSManagedObjectContext {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options: [AnyHashable: Any] = [NSPersistentHistoryTrackingKey: true,
                                           NSPersistentStoreRemoteChangeNotificationPostOptionKey: true,
                                           NSMigratePersistentStoresAutomaticallyOption: true,
                                           NSInferMappingModelAutomaticallyOption: true]
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

}
