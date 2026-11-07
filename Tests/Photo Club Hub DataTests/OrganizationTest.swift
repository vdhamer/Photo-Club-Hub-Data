//
//  OrganizationTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 13/09/2025.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext

@MainActor @Suite("Tests the Core Data Organization class") struct OrganizationTests {

    private let testPersistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private let english: Language
    private let dutch: Language

    init () {
        // Use a private in-memory store rather than PersistenceController.shared. Sharing the singleton
        // coordinator across parallel suites deadlocks (main-queue performAndWait fetches contending with
        // background-context saves) and lets suites pollute each other's records. See issue #756.
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

    @Test("FullnameTown for Fotogroep Waalre in Aalst") func fotogroepWaalreInAalst() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "Aalst"
        #expect(club.fullNameTown == "\(club.fullName) (\(club.town))")
    }

    @Test("FullnameTown for Fotogroep Waalre in Waalre") func fotogroepWaalreInWaalre() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "Waalre"
        #expect(club.fullNameTown == "\(club.fullName)")
    }

    @Test("FullnameTown for Fotogroep Waalre in waalre") func fotogroepWaalreInwaalre() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "waalre"
        #expect(club.fullNameTown == "\(club.fullName) (\(club.town))")
    }

    @Test("FullnameTown for Fotogroep Waalre in to") func fotogroepWaalreInto() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "to" // why does this test exist?
        #expect(club.fullNameTown == "\(club.fullName) (\(club.town))")
    }

    @Test("FullnameTown for Fotogroep Waalre in Waal") func fotogroepWaalreWaal() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "Waal" // this is why Natural Language Processing is needed
        #expect(club.fullNameTown == "\(club.fullName) (\(club.town))")
    }

    @Test("FullnameTown for Fotoclub Den Dungen in Den Dungen") func fotoclubDenDungenDD() throws {
        let club = Organization(context: context)
        club.fullName = "Fotoclub Den Dungen"
        club.town = "Den Dungen" // this is where Natural Language Processing is thinks town is 2 words
        #expect(club.fullNameTown == "\(club.fullName)")
    }

    @Test("FullnameTown for Fotokring Sint-Michielsgestel in Den Dungen") func fotokringSintMichielsgestelSM() throws {
        let club = Organization(context: context)
        club.fullName = "Fotokring Sint-Michielsgestel"
        club.town = "Sint-Michielsgestel" // this is where Natural Language Processing is thinks town is 2 words
        #expect(club.fullNameTown == "\(club.fullName)")
    }

    // MARK: - fullNameLocalizedTown(for:) (Data#88)

    // Stores the town Apple's geocoder would have returned for `organization` in `language`.
    private func storeLocalizedTown(_ localizedTown: String, for organization: Organization, in language: Language) {
        let fields = LocalizedAddressFields(localizedTown: localizedTown, localizedCountry: "ExampleCountry")
        LocalizedAddress.findCreateUpdate(bgContext: context,
                                          organization: organization,
                                          language: language,
                                          newLocalizedAddressFields: fields,
                                          newCoordinates: organization.coordinates)
    }

    @Test("fullNameLocalizedTown() shows a foreign town in the output language") func foreignTownLocalized() throws {
        let museum = Organization(context: context)
        museum.fullName = "Museum Ludwig"
        museum.town = "Köln"
        storeLocalizedTown("Keulen", for: museum, in: dutch)
        storeLocalizedTown("Cologne", for: museum, in: english)

        #expect(museum.fullNameLocalizedTown(for: dutch) == "\(museum.fullName) (Keulen)")
        #expect(museum.fullNameLocalizedTown(for: english) == "\(museum.fullName) (Cologne)")
        #expect(museum.fullNameTown == "\(museum.fullName) (Köln)") // the identity form keeps the stored town
    }

    @Test("fullNameLocalizedTown() doesn't append (town) if the name already contains the canonical version of town")
    func nameContainsStoredTown() throws {
        let museum = Organization(context: context)
        museum.fullName = "Fotomuseum Den Haag"
        museum.town = "Den Haag" // in local language as long as character set is Latin-based
        storeLocalizedTown("Den Haag", for: museum, in: dutch)
        storeLocalizedTown("The Hague", for: museum, in: english)

        #expect(museum.fullNameLocalizedTown(for: dutch) == museum.fullName)
        #expect(museum.fullNameLocalizedTown(for: english) == museum.fullName) // not "(The Hague)"
    }

    @Test("fullNameLocalizedTown() leaves out a town the name contains only as localized")
    func nameContainsOnlyLocalizedTown() throws {
        let museum = Organization(context: context)
        museum.fullName = "Museum Cologne"
        museum.town = "Köln" // in local language as long as character set is Latin-based
        storeLocalizedTown("Keulen", for: museum, in: dutch)
        storeLocalizedTown("Cologne", for: museum, in: english)

        #expect(museum.fullNameLocalizedTown(for: english) == museum.fullName)
        #expect(museum.fullNameLocalizedTown(for: dutch) == "\(museum.fullName) (Keulen)") // name has neither town
    }

    @Test("fullNameLocalizedTown() falls back to the canonical town if there is no LocalizedAddress")
    func noLocalizedAddressFallsBack() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "Aalst"

        #expect(club.localizedAddress(for: dutch) == nil)
        #expect(club.fullNameLocalizedTown(for: dutch) == "\(club.fullName) (Aalst)")
    }

    @Test("fullNameLocalizedTown() falls back to the canonical town instead of showing Town?")
    func unknownLocalizedTownFallsBack() throws {
        let club = Organization(context: context)
        club.fullName = "Fotogroep Waalre"
        club.town = "Aalst"
        storeLocalizedTown(LocalizedAddress.unknownTown, for: club, in: english)

        #expect(club.localizedTown(for: english) == LocalizedAddress.unknownTown)
        #expect(club.fullNameLocalizedTown(for: english) == "\(club.fullName) (Aalst)")
    }

}
