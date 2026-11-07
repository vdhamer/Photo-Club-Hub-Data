//
//  MemberPortfolio+rolesTest.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 07/11/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

// roleDescriptionOfClubTown(language:) returns a string such as "Member of Fotogroep Argus ('s-Hertogenbosch)".
//
// Two parts depend on the language: the words ("Member", "of") and the club's town. The town must match the
// Clubs tab section header shown above the string (Data#99), so that is what these tests check.
//
// These tests only check the end of the string (the club and its town), because the other words can't be checked here:
// `swift test` copies PhotoClubHubData.xcstrings into the bundle uncompiled, so each word comes back as its key
// (such as "of2"). An Xcode build compiles the catalog into en.lproj and nl.lproj and would return a localization.
@MainActor @Suite("Tests MemberPortfolio+roles") struct MemberPortfolioRolesTests {

    // MARK: - initialization

    private let testPersistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private let english: Language // initialized in init()
    private let dutch: Language

    init () {
        // Use a private in-memory store rather than PersistenceController.shared. See issue #756.
        testPersistenceController = PersistenceController(inMemory: true)
        context = testPersistenceController.container.viewContext
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // Supported as Level 0 would mark them, without reading a Level 0 file.
        english = Language.findCreateUpdate(context: context,
                                            isoCode: "en",
                                            nameENOptional: nil,
                                            isSupportedOptional: true)
        dutch = Language.findCreateUpdate(context: context,
                                          isoCode: "nl",
                                          nameENOptional: nil,
                                          isSupportedOptional: true)
    }

    // MARK: - utilities

    // Creates an organization with one member, John Doe.
    private func member(fullName: String, town: String) -> MemberPortfolio {
        let organization = Organization(context: context)
        organization.fullName = fullName
        organization.town = town

        let photographer = Photographer.findCreateUpdate(context: context,
                                                         personName: PersonName(givenName: "John",
                                                                                infixName: "",
                                                                                familyName: "Doe"))
        return MemberPortfolio.findCreateUpdate(bgContext: context,
                                                organization: organization,
                                                photographer: photographer)
    }

    // Stores the town Apple's geocoder would have returned for `organization` in `language`.
    private func storeLocalizedTown(_ localizedTown: String, for organization: Organization, in language: Language) {
        let fields = LocalizedAddressFields(localizedTown: localizedTown, localizedCountry: "ExampleCountry")
        LocalizedAddress.findCreateUpdate(bgContext: context,
                                          organization: organization,
                                          language: language,
                                          newLocalizedAddressFields: fields,
                                          newCoordinates: organization.coordinates)
    }

    // MARK: - the tests

    @Test("Role string shows the club's town in the given language") func roleStringShowsLocalizedTown() {
        let member = member(fullName: "Fotoclub Rheinland", town: "Köln") // fictional club
        storeLocalizedTown("Keulen", for: member.organization, in: dutch)
        storeLocalizedTown("Cologne", for: member.organization, in: english)

        #expect(member.roleDescriptionOfClubTown(language: dutch).hasSuffix(" Fotoclub Rheinland (Keulen)"))
        #expect(member.roleDescriptionOfClubTown(language: english).hasSuffix(" Fotoclub Rheinland (Cologne)"))
        #expect(member.roleDescriptionOfClubTown(language: nil).hasSuffix(" Fotoclub Rheinland (Köln)")) // stored town
    }

    @Test("Role string shows the stored town if there is no LocalizedAddress")
    func roleStringWithoutLocalizedAddressShowsStoredTown() {
        let member = member(fullName: "Fotogroep Waalre", town: "Aalst")

        #expect(member.organization.localizedAddress(for: dutch) == nil)
        #expect(member.roleDescriptionOfClubTown(language: dutch).hasSuffix(" Fotogroep Waalre (Aalst)"))
    }

    @Test("Role string shows the stored town instead of Town?") func roleStringWithUnknownTownShowsStoredTown() {
        let member = member(fullName: "Fotogroep Waalre", town: "Aalst")
        storeLocalizedTown(LocalizedAddress.unknownTown, for: member.organization, in: english)

        #expect(member.organization.localizedTown(for: english) == LocalizedAddress.unknownTown)
        #expect(member.roleDescriptionOfClubTown(language: english).hasSuffix(" Fotogroep Waalre (Aalst)"))
    }

    @Test("Role string doesn't append (town) if the name already contains it")
    func roleStringNameContainsTownHasNoSuffix() {
        let member = member(fullName: "Fotoclub Den Haag", town: "Den Haag") // fictional club
        storeLocalizedTown("The Hague", for: member.organization, in: english)

        #expect(member.roleDescriptionOfClubTown(language: english).hasSuffix(" Fotoclub Den Haag")) // no "(The Hague)"
    }

    @Test("Role string of a row without organization or photographer is the role description alone")
    func roleStringWithoutOrganization() {
        let orphan = MemberPortfolio(context: context) // relationships are nil, as on a deleted row (#802)
        let member = member(fullName: "Fotogroep Waalre", town: "Aalst")

        #expect(orphan.organization_ == nil && orphan.photographer_ == nil)
        let orphanString = orphan.roleDescriptionOfClubTown(language: dutch) // must not trap
        #expect(!orphanString.isEmpty)
        let memberString = member.roleDescriptionOfClubTown(language: dutch)
        #expect(memberString.hasPrefix("\(orphanString) ")) // same roles, with " of <club>" appended
        #expect(!orphanString.contains(member.organization.fullName))
    }

}
