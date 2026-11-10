//
//  OrganizationFindCreateUpdateTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 29/06/2026.
//
//  Covers Organization.findCreateUpdate idempotency and the throwing Organization.find(...) lookups.
//  The other test file OrganizationTest.swift covers the fullNameTown computed property.
//

import Testing // for macros like `expect`
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

@MainActor @Suite("Tests Organization.findCreateUpdate & Organization.find") struct OrganizationFindCreateUpdateTests {

    private let testPersistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext
    private let idPlus = OrganizationIdPlus(fullName: "UnitTest Club", town: "UnitTestTown", nickname: "nick")

    init () {
        // Use a private in-memory store rather than PersistenceController.shared. Sharing the singleton
        // coordinator across parallel suites deadlocks (main-queue performAndWait fetches contending with
        // background-context saves) and lets suites pollute each other's records. See issue #756.
        testPersistenceController = PersistenceController(inMemory: true)
        viewContext = testPersistenceController.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // Counts Organization records matching the (fullName, town) identity.
    private func count(_ id: OrganizationID) -> Int {
        let predicate = NSPredicate(format: "fullName_ = %@ AND town_ = %@", // avoid localization
                                    argumentArray: [id.fullName, id.town])
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        return ((try? viewContext.fetch(fetchRequest)) ?? []).count
    }

    // MARK: - idempotency

    // Calling findCreateUpdate twice with the same identity must return the same object (no duplicate).
    @Test("findCreateUpdate is idempotent for an identical idPlus") func idempotentForSameIdPlus() {
        let org1 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)
        let org2 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)

        #expect(org1 === org2) // same managed object, not a second copy
        #expect(count(idPlus.id) == 1) // exactly one record exists for this identity
        #expect(org1.fullName == idPlus.fullName)
        #expect(org1.town == idPlus.town)
    }

    // MARK: - organizationType is non-identifying

    // Identity is (fullName, town); organizationType is not part of it, and is only set when the
    // organization is first created (never changed on a later update). So a second findCreateUpdate
    // with the same name+town but a different type returns the SAME object with its ORIGINAL type -
    // you cannot have a club and a museum with the same name in the same town.
    @Test("same name+town cannot become a second organization of a different type")
    func sameNameTownDifferentTypeIsSameObject() {
        let asClub = Organization.findCreateUpdate(context: viewContext,
                                                   organizationTypeEnum: .club,
                                                   idPlus: idPlus)
        let asMuseum = Organization.findCreateUpdate(context: viewContext,
                                                     organizationTypeEnum: .museum,
                                                     idPlus: idPlus)

        #expect(asMuseum === asClub) // same object, not a second row
        #expect(count(idPlus.id) == 1) // still exactly one organization
        // type stayed as first created (.club); the requested .museum was silently ignored
        #expect(asClub.organizationType.organizationTypeName == OrganizationTypeEnum.club.rawValue)
    }

    // MARK: - nickname is non-identifying

    // The data model constrains identity on (fullName, town), NOT on nickName, so two distinct
    // organizations are allowed to share a nickname. This pins down that intended behavior.
    // Note: we deliberately do NOT call Organization.find(nickname:) here - with duplicate
    // nicknames it hits ifDebugFatalError, which would crash this (debug) test run.
    @Test("two organizations may share a nickname (nickname is non-identifying)")
    func duplicateNicknameAllowed() {
        let sharedNickname = "dup" // both organizations will use this nickname

        let org1 = Organization.findCreateUpdate(
            context: viewContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(fullName: "UnitTest Club A",
                                       town: "UnitTestTownA",
                                       nickname: sharedNickname))
        let org2 = Organization.findCreateUpdate(
            context: viewContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(fullName: "UnitTest Club B",
                                       town: "UnitTestTownB",
                                       nickname: sharedNickname))

        #expect(org1 !== org2) // genuinely two different organizations
        #expect(org1.nickName == sharedNickname)
        #expect(org2.nickName == sharedNickname)

        // both records coexist: no uniqueness constraint on nickName
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "nickName_ = %@", argumentArray: [sharedNickname])
        #expect(((try? viewContext.fetch(fetchRequest)) ?? []).count == 2)
    }

    // nickName is updated like the other non-identifying fields, so a changed nickname reaches an existing
    // install without a data reset (Data#75). For an organization with a hardcoded MembersProvider, Level 2 writes the
    // provider's nickname after Level 1, so a change must be made in the Level 1 entry, the provider, and the
    // Level 2 file's name and "club" block together (until Data#8 retires the providers).
    @Test("a changed nickname replaces the stored one") func changedNicknameIsApplied() {
        let newNickname = "renamed"

        let org1 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)
        #expect(org1.nickName == idPlus.nickname)

        let org2 = Organization.findCreateUpdate(
            context: viewContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(id: idPlus.id, nickname: newNickname))
        #expect(org2 === org1) // same object: nickname is not part of the identity
        #expect(org2.nickName == newNickname)
    }

    // A missing nickname reaches update() as "", which must leave the stored nickname alone (Data#75).
    @Test("an empty nickname does not overwrite the stored one") func emptyNicknameDoesNotOverwrite() {
        let org1 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)
        let org2 = Organization.findCreateUpdate(
            context: viewContext,
            organizationTypeEnum: .club,
            idPlus: OrganizationIdPlus(id: idPlus.id, nickname: ""))
        #expect(org2 === org1) // same object
        #expect(org2.nickName == idPlus.nickname) // unchanged by the empty nickname
    }

    // MARK: - nil update semantics

    // A nil optional field must leave an already-set value untouched.
    @Test("nil optional field does not overwrite an existing value") func nilOptionalFieldDoesNotOverwrite() {
        let email = "test@example.com"

        let org1 = Organization.findCreateUpdate(
            context: viewContext,
            organizationTypeEnum: .club,
            idPlus: idPlus,
            optionalFields: OrganizationOptionalFields(maintainerEmail: email))
        #expect(org1.maintainerEmail == email)

        // default optionalFields has maintainerEmail == nil
        let org2 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)
        #expect(org2 === org1) // same object
        #expect(org2.maintainerEmail == email) // unchanged by the nil call
    }

    // MARK: - throwing find(...) lookups

    @Test("find(organizationID:) returns a known organization") func findKnownOrganizationID() throws {
        let created = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)

        let found = try Organization.find(context: viewContext, organizationID: idPlus.id)
        #expect(found === created) // same object
    }

    @Test("find(organizationID:) throws for an unknown organization") func findUnknownOrganizationIDThrows() {
        let unknownID = OrganizationID(fullName: "NoSuch Club",
                                       town: "NoSuchTown")
        #expect(throws: (any Error).self) {
            _ = try Organization.find(context: viewContext, organizationID: unknownID)
        }
    }

    @Test("find(nickname:) returns a known organization") func findKnownNickname() throws {
        let created = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)

        let found = try Organization.find(context: viewContext, nickname: idPlus.nickname)
        #expect(found === created)
    }

    @Test("find(nickname:) throws for an unknown nickname") func findUnknownNicknameThrows() {
        let unknownNickname = "noSuchNick"
        #expect(throws: (any Error).self) {
            _ = try Organization.find(context: viewContext, nickname: unknownNickname)
        }
    }

    // MARK: - identity uses plain typography (Data#100)

    @Test("a name with a curly apostrophe is stored with a plain one, and found with either")
    func curlyApostropheIsStoredPlain() throws {
        let curly = OrganizationIdPlus(fullName: "Dia- en Fotoclub ’s-Gravenzande", town: "’s-Gravenzande",
                                       nickname: "fcDiaGravenzande")
        let plain = OrganizationID(fullName: "Dia- en Fotoclub 's-Gravenzande", town: "'s-Gravenzande")

        let org1 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: curly)
        #expect(org1.fullName == "Dia- en Fotoclub 's-Gravenzande")
        #expect(org1.town == "'s-Gravenzande")

        let org2 = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: curly)
        #expect(org2 === org1) // a second load of the same JSON finds the same organization
        #expect(try Organization.find(context: viewContext, organizationID: plain) === org1)
        #expect(count(plain) == 1)
    }

    @Test("the fullName and town setters store plain typography") func settersStorePlain() {
        let organization = Organization(context: viewContext)
        organization.fullName = "MOMus–Thessaloniki Museum of Photography"
        organization.town = "Thessaloniki\u{00A0}Centre"

        #expect(organization.fullName_ == "MOMus-Thessaloniki Museum of Photography")
        #expect(organization.town_ == "Thessaloniki Centre")
    }

    @Test("a nickname is stored with plain typography, and found with either form")
    func nicknameIsStoredPlain() throws {
        let curly = OrganizationIdPlus(fullName: "Witte’s Museum voor Fotografie en Radio", town: "Tuitjenhorn",
                                       nickname: "Witte’s Museum")
        #expect(curly.nickname == "Witte's Museum")

        let organization = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .museum,
                                                         idPlus: curly)
        #expect(organization.nickName_ == "Witte's Museum")
        #expect(try Organization.find(context: viewContext, nickname: "Witte’s Museum") === organization)
        #expect(try Organization.find(context: viewContext, nickname: "Witte's Museum") === organization)

        organization.nickName = "Witte’s"
        #expect(organization.nickName_ == "Witte's")
    }

    @Test("a remark is stored with plain typography, and an unchanged remark isn't an update")
    func remarkIsStoredPlain() {
        let organization = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club,
                                                         idPlus: idPlus)
        let dutch = Language.findCreate(context: viewContext, isoCode: "nl")
        let curly = "Foto’s worden besproken op een “forumavond”,\u{00A0}elke maand."

        #expect(LocalizedRemark.findCreateUpdate(bgContext: viewContext, organization: organization,
                                                 language: dutch, localizedString: curly))
        let remarks = (organization.localizedRemarks_ as? Set<LocalizedRemark>) ?? []
        #expect(remarks.map(\.localizedString) == ["Foto's worden besproken op een \"forumavond\", elke maand."])

        // the next load of the same JSON compares the normalized text, so it changes nothing
        #expect(LocalizedRemark.findCreateUpdate(bgContext: viewContext, organization: organization,
                                                 language: dutch, localizedString: curly) == false)
    }

    @Test("a changed remark replaces the stored one on the next load") func changedRemarkIsUpdated() {
        // Two loads in their own background contexts, configured like the app's (mergeByPropertyStoreTrump), so a
        // second row caught by the uniqueness constraint would silently keep the stored text.
        let container = testPersistenceController.container
        for text in ["old text", "new text"] {
            let bgContext = LevelLoader.makeBgContext(ctxName: "load \(text)", usedContainer: container)
            bgContext.performAndWait {
                let organization = Organization.findCreateUpdate(context: bgContext, organizationTypeEnum: .club,
                                                                 idPlus: idPlus)
                let dutch = Language.findCreate(context: bgContext, isoCode: "nl")
                _ = LocalizedRemark.findCreateUpdate(bgContext: bgContext, organization: organization,
                                                     language: dutch, localizedString: text)
                try? bgContext.save()
            }
        }

        let request = NSFetchRequest<LocalizedRemark>(entityName: "LocalizedRemark")
        let remarks = (try? viewContext.fetch(request)) ?? []
        #expect(remarks.map(\.localizedString) == ["new text"])
    }

    // MARK: - level2URL (Data#102)

    @Test("a museum has no level2URL, and none is built from its nickname") func museumHasNoLevel2URL() {
        // a nickname that breaks the rule must not matter: the museum check comes before any URL is built
        let museumIdPlus = OrganizationIdPlus(fullName: "Fotomuseum aan het Vrijthof", town: "Maastricht",
                                              nickname: "F/M Vrijthof")
        let museum = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .museum,
                                                   idPlus: museumIdPlus)
        #expect(museum.level2URL == nil)
    }

    @Test("a club without its own level2URL gets the default one") func clubGetsDefaultLevel2URL() {
        let club = Organization.findCreateUpdate(context: viewContext, organizationTypeEnum: .club, idPlus: idPlus)
        #expect(club.level2URL?.absoluteString == "https://www.vdhamer.com/nick/index.html")
    }

}
