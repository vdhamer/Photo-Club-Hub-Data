//
//  Level2JsonReaderTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 05/03/2025.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

@MainActor @Suite("Tests the Level 2 JSON reader") struct Level2JsonReaderTests {

    private let testPersistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext

    init () {
        // Each test gets its own private in-memory store, so the app's concurrent background
        // data-loading into PersistenceController.shared can't pollute the Expertise/PhotographerExpertise
        // counts below. Swift Testing creates a fresh suite instance (and thus a fresh init) per test, so
        // the store is effectively per-test — no deletion or cross-test isolation needed.
        testPersistenceController = PersistenceController(inMemory: true) // inMemory is important for isolation
        viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // The empty store lacks several constant records the app seeds at launch; seed them here.
        // Providers create .club organizations that reference OrganizationType, so both are needed.
        // Must run on the main-queue viewContext (initConstants does a bare `save()`). See #749.
        Language.initConstants(context: viewContext)
        OrganizationType.initConstants(context: viewContext)
    }

    // Loads a frozen Level 2 fixture the way a club's *MembersProvider loads its production file: create the
    // club under `idPlus` first, so the assertions can find it in its random town, then read the file.
    // The providers themselves cannot be used here. They request the club's real nickname, and a production
    // file of that name is found before the fixture, so the test would silently read production data.
    // See "Tests run against frozen data" in README.md.
    private func loadFixture(_ idPlus: OrganizationIdPlus, into bgContext: NSManagedObjectContext) async {
        await bgContext.perform {
            _ = Organization.findCreateUpdate(context: bgContext, organizationTypeEnum: .club, idPlus: idPlus)
        }
        await Level2JsonReader.load(bgContext: bgContext,
                                    organizationIdPlus: idPlus,
                                    isBeingTested: true, // skips checking the file's town against idPlus.town
                                    useOnlyInBundleFile: true)
    }

    // Read TemplateMinTest.level2.json and check for parsing errors.
    @Test("Parse TemplateMinTest.level2.json") func templateMinParse() async {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = "TemplateMinTest"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true

        #expect(Expertise.count(context: bgContext) == 0) // clearing is handled via "inMemory: true"

        let randomTownForTesting = String.random(length: 10) // e.g. "s8H2bEU3C6"
        let idPlus = OrganizationIdPlus(fullName: "Template Club With Minimal Data",
                                        town: randomTownForTesting, // town to keep this separate from normal club data
                                        nickname: "TemplateMinTest")
        await loadFixture(idPlus, into: bgContext)

        let predicateFormat: String = "town_ = %@" // avoid localization
        // Note that organizationType is not an identifying attribute.
        // This implies that you cannot have 2 organizations with the same Name and Town, but of a different type.
        let predicate = NSPredicate(format: predicateFormat,
                                    argumentArray: [ randomTownForTesting ] )
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        let organizations: [Organization] = (try? viewContext.fetch(fetchRequest)) ?? []

        #expect(Expertise.count(context: bgContext) == 0) // this particular club has no expertises (it is "minimal")
        #expect(PhotographerExpertise.count(context: bgContext) == 0)  // A club without PhotographerExpertises

        #expect(organizations.count == 1)
        if organizations.isEmpty == false {
            #expect(organizations[0].organizationType.organizationTypeName == OrganizationTypeEnum.club.rawValue)
            #expect(organizations[0].fullName == idPlus.fullName)
            #expect(organizations[0].town == idPlus.town)
            #expect(organizations[0].nickName == idPlus.nickname)
        }

    }

    // Read TemplateMaxTest.level2.json and check for parsing errors
    @Test("Parse TemplateMaxTest.level2.json") func templateMaxParse() async {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = "TemplateMaxTest"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true

        #expect(Expertise.count(context: bgContext) == 0)

        let randomTownForTesting = String.random(length: 10)
        let idPlus = OrganizationIdPlus(fullName: "Template Club With Maximal Data",
                                        town: randomTownForTesting, // town to distinguish this from normal club data
                                        nickname: "TemplateMaxTest")
        await loadFixture(idPlus, into: bgContext)

        let predicateFormat: String = "town_ = %@" // avoid localization
        // Note that organizationType is not an identifying attribute.
        // This implies that you cannot have 2 organizations with the same Name and Town, but of a different type.
        let predicate = NSPredicate(format: predicateFormat,
                                    argumentArray: [ randomTownForTesting ] )
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        let organizations: [Organization] = (try? viewContext.fetch(fetchRequest)) ?? []

        #expect(Expertise.count(context: bgContext) == 5) // Mien's 2 + Mike's 5
        #expect(PhotographerExpertise.count(context: bgContext, expertiseID: "Landscape") == 1) // that would be Mike

        #expect(organizations.count == 1)
        if organizations.isEmpty == false {
            #expect(organizations[0].organizationType.organizationTypeName == OrganizationTypeEnum.club.rawValue)
            #expect(organizations[0].fullName == idPlus.fullName)
            #expect(organizations[0].town == idPlus.town)
            #expect(organizations[0].nickName == idPlus.nickname)
        }
    }

    // Read fgDeGenderTest.level2.json and check for parsing errors
    @Test("Parse fgDeGenderTest.level2.json") func fgDeGenderParse() async {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = "fgDeGender"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true

        // Deletion must run on the main-queue viewContext: deleteCoreDataObjects is a @MainActor
        // main-thread API (its bare save() would trip _PFAssertSafeMultiThreadedAccess off-queue). See #749.
        Model.deleteExpertises(viewContext: viewContext)
        #expect(Expertise.count(context: bgContext) == 0)

        let randomTownForTesting = String.random(length: 10)
        let idPlus = OrganizationIdPlus(fullName: "Fotogroep de Gender",
                                        town: randomTownForTesting, // town to distinguish this from normal club data
                                        nickname: "fgDeGenderTest")
        await loadFixture(idPlus, into: bgContext) // The club has Expertises

        let predicateFormat: String = "town_ = %@" // avoid localization
        // Note that organizationType is not an identifying attribute.
        // This implies that you cannot have 2 organizations with the same Name and Town, but of a different type.
        let predicate = NSPredicate(format: predicateFormat,
                                    argumentArray: [ randomTownForTesting ] )
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        let organizations: [Organization] = (try? viewContext.fetch(fetchRequest)) ?? []

        #expect(organizations.count == 1)
        if organizations.isEmpty == false {
            #expect(organizations[0].organizationType.organizationTypeName == OrganizationTypeEnum.club.rawValue)
            #expect(organizations[0].fullName == idPlus.fullName)
            #expect(organizations[0].town == idPlus.town)
            #expect(organizations[0].nickName == idPlus.nickname)
            #expect(organizations[0].fotobondClubNumber?.id == nil) // club in randomTown → no fotobondNumber
        }

        #expect(Expertise.count(context: bgContext) == 21)
        #expect(PhotographerExpertise.count(context: bgContext, expertiseID: "Minimal") == 2)
        #expect(PhotographerExpertise.count(context: bgContext) == 49)
    }

    // Read and check for expertise merging
    @Test("Load 2 clubs with expertise data for same photographer") func fgWaalreFgDeGender() async {
        let bgContext = testPersistenceController.container.newBackgroundContext()
        bgContext.name = "fgDeGender"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true

        // Deletion must run on the main-queue viewContext: deleteCoreDataObjects is a @MainActor
        // main-thread API (its bare save() would trip _PFAssertSafeMultiThreadedAccess off-queue). See #749.
        Model.deleteExpertises(viewContext: viewContext) // remove Expertises
        #expect(Expertise.count(context: bgContext) == 0)

        await loadFixture(OrganizationIdPlus(fullName: "Fotogroep de Gender",
                                             town: String.random(length: 10),
                                             nickname: "fgDeGenderTest"),
                          into: bgContext)
        #expect(Expertise.count(context: bgContext) == 21)
        #expect(PhotographerExpertise.count(context: bgContext) == 49)

        await loadFixture(OrganizationIdPlus(fullName: "Fotogroep Waalre",
                                             town: String.random(length: 10),
                                             nickname: "fgWaalreTest"),
                          into: bgContext)

        #expect(Expertise.count(context: bgContext) == 22)
        #expect(PhotographerExpertise.count(context: bgContext) == 49 + 44 - 2) // DeGender + Waalre - overlap
    }

}
