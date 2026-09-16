//
//  GeocodingCountsTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code under guidance of Peter van den Hamer on 16/09/2026.
//
//  Covers LocalizedAddress.geocodingCounts, which counts (organization × supported language) combinations
//  by the state of their translated address, and Organization.needsLocalizedAddress, the rule it shares
//  with OrganizationGeocoder.buildWorkItems (Data#57).
//

import Testing      // for macros like `expect`
@testable import Photo_Club_Hub_Data
import CoreData     // for NSManagedObjectContext
import CoreLocation // for CLLocationCoordinate2D

@MainActor @Suite("Tests the geocoding counts") struct GeocodingCountsTests {

    private let persistenceControllerForTesting: PersistenceController
    private let viewContext: NSManagedObjectContext

    // Two supported languages, as production has: the counts are per (organization, supported language) pair.
    private let english: Language // assigned during init()
    private let dutch: Language

    private let amsterdamCoords = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
    private let rotterdamCoords = CLLocationCoordinate2D(latitude: 51.9244, longitude: 4.4777)

    init () {
        // A private in-memory store per test. See issue #756.
        persistenceControllerForTesting = PersistenceController(inMemory: true)
        viewContext = persistenceControllerForTesting.container.viewContext
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // Flags set here rather than by reading Level 0: this suite is about the counts, not about the file.
        english = Language.findCreateUpdate(context: viewContext,
                                            isoCode: "en",
                                            isSupportedOptional: true)
        dutch = Language.findCreateUpdate(context: viewContext,
                                          isoCode: "nl",
                                          isSupportedOptional: true)
        // An unsupported language must stay out of every count, including out of `total`.
        _ = Language.findCreateUpdate(context: viewContext,
                                      isoCode: "de",
                                      isSupportedOptional: false)
    }

    private func makeOrganization(at coordinates: CLLocationCoordinate2D) -> Organization {
        let idPlus = OrganizationIdPlus(fullName: "UnitTest Club \(String.random(length: 10))",
                                        town: "UnitTestTown\(String.random(length: 10))",
                                        nickname: "nick\(String.random(length: 10))")
        let organization = Organization.findCreateUpdate(context: viewContext,
                                                         organizationTypeEnum: .club,
                                                         idPlus: idPlus)
        organization.coordinates = coordinates
        return organization
    }

    @discardableResult // can ignore the Bool without assigning it so "_"
    private func storeAddress(for organization: Organization,
                              in language: Language,
                              town: String,
                              country: String,
                              derivedFrom coordinates: CLLocationCoordinate2D) -> Bool {
        LocalizedAddress.findCreateUpdate(bgContext: viewContext,
                                          organization: organization,
                                          language: language,
                                          newLocalizedAddressFields: LocalizedAddressFields(localizedTown: town,
                                                                                            localizedCountry: country),
                                          newCoordinates: coordinates)
    }

    private func geocodingCounts() -> GeocodingCounts {
        LocalizedAddress.geocodingCounts(context: viewContext)
    }

    // MARK: - the three states

    // No rows yet: both combinations of the one organization are waiting for Apple.
    @Test("an organization without addresses waits in every supported language") func noAddressesYet() {
        _ = makeOrganization(at: amsterdamCoords)

        let counts = geocodingCounts()

        #expect(counts.total == 2) // one organization × two supported languages; German does not count here
        #expect(counts.waiting == 2)
        #expect(counts.completed == 0)
        #expect(counts.onErrorPlaceholders == 0)
    }

    // A real town and country, derived from the coordinates the organization still has.
    @Test("current addresses in both languages count as completed") func bothLanguagesCurrent() {
        let organization = makeOrganization(at: amsterdamCoords)
        storeAddress(for: organization, in: english, town: "Amsterdam", country: "Netherlands",
                     derivedFrom: amsterdamCoords)
        storeAddress(for: organization, in: dutch, town: "Amsterdam", country: "Nederland",
                     derivedFrom: amsterdamCoords)

        let counts = geocodingCounts()

        #expect(counts.completed == 2)
        #expect(counts.waiting == 0)
        #expect(counts.onErrorPlaceholders == 0)
    }

    // The organization moved: the stored address was derived from coordinates it no longer has.
    @Test("an address derived from older coordinates is waiting again") func organizationMoved() {
        let organization = makeOrganization(at: amsterdamCoords)
        storeAddress(for: organization, in: english, town: "Amsterdam", country: "Netherlands",
                     derivedFrom: rotterdamCoords)
        storeAddress(for: organization, in: dutch, town: "Amsterdam", country: "Nederland",
                     derivedFrom: rotterdamCoords)

        organization.coordinates = amsterdamCoords // e.g. corrected in the Level 1 JSON

        let counts = geocodingCounts()

        #expect(counts.waiting == 2)
        #expect(counts.completed == 0)
        #expect(organization.needsLocalizedAddress(for: english)) // the shared rule agrees
        #expect(organization.needsLocalizedAddress(for: dutch)) // the shared rule agrees
    }

    // Apple's server answered for these coordinates, but without a city: the placeholder is not asked again.
    @Test("a stored placeholder counts apart from waiting") func placeholderStored() {
        let organization = makeOrganization(at: amsterdamCoords)
        storeAddress(for: organization, in: english, town: LocalizedAddress.unknownTown, country: "Netherlands",
                     derivedFrom: amsterdamCoords)
        storeAddress(for: organization, in: dutch, town: "Amsterdam", country: "Nederland",
                     derivedFrom: amsterdamCoords)

        let counts = geocodingCounts()

        #expect(counts.onErrorPlaceholders == 1)
        #expect(counts.completed == 1)
        #expect(counts.waiting == 0) // a placeholder is an answer: the geocoder will not ask again
    }

    // An unknown country is the other half of the same case.
    @Test("an unknown country also counts as a placeholder") func unknownCountryStored() {
        let organization = makeOrganization(at: amsterdamCoords)
        storeAddress(for: organization, in: english, town: "Amsterdam",
                     country: LocalizedAddress.unknownCountry, derivedFrom: amsterdamCoords)

        let counts = geocodingCounts()

        #expect(counts.onErrorPlaceholders == 1)
        #expect(counts.waiting == 1) // the Dutch combination has no row at all
    }

    // MARK: - the edge cases

    // Before Level 0 flags anything, there is nothing to count, and no optional to unwrap.
    @Test("no supported languages gives all zeros") func noSupportedLanguages() {
        _ = makeOrganization(at: amsterdamCoords)
        for language in [english, dutch] {
            language.isSupported = false
        }

        let counts = geocodingCounts()

        #expect(counts.total == 0)
        #expect(counts.completed == 0)
        #expect(counts.waiting == 0)
        #expect(counts.onErrorPlaceholders == 0)
    }

    // The invariant the struct is built around: total is derived by summing 3 parts. Should always add up.
    @Test("the parts always add up to total") func partsAddUp() {
        let amsterdam = makeOrganization(at: amsterdamCoords)
        let rotterdam = makeOrganization(at: rotterdamCoords)
        storeAddress(for: amsterdam, in: english,
                     town: "Amsterdam", country: "Netherlands",
                     derivedFrom: amsterdamCoords)
        storeAddress(for: amsterdam, in: dutch,
                     town: LocalizedAddress.unknownTown, country: "Nederland",
                     derivedFrom: amsterdamCoords)
        storeAddress(for: rotterdam, in: english,
                     town: "Rotterdam", country: "Netherlands",
                     derivedFrom: amsterdamCoords)

        let counts = geocodingCounts()

        #expect(counts.total == 4) // two organizations × two supported languages
        #expect(counts.total == counts.completed + counts.waiting + counts.onErrorPlaceholders) // by definition
        #expect(counts.completed == 1) // Amsterdam in English
        #expect(counts.onErrorPlaceholders == 1) // Amsterdam in Dutch
        #expect(counts.waiting == 2) // Rotterdam in Dutch never provided, Rotterdam in English changed its coordinates
    }
}
