//
//  OrganizationStatusTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 22/11/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import Foundation // for Bundle

// The labels that the apps show with a ghost organization (Data#116).
@Suite("Tests the labels of OrganizationStatus") struct OrganizationStatusTests {

    @Test("The raw values are the JSON values") func rawValuesAreJsonValues() {
        #expect(OrganizationStatus.allCases.map(\.rawValue) == ["rejected", "active", "inactive", "possiblyInactive"])
    }

    @Test("Only the two inactive statuses have a label") func onlyInactiveHaveLabel() {
        let english = Bundle.photoClubHubDataModuleForLanguage("en")
        #expect(OrganizationStatus.rejected.displayNameForHTML(languageBundle: english) == nil)
        #expect(OrganizationStatus.active.displayNameForHTML(languageBundle: english) == nil)
        #expect(OrganizationStatus.inactive.displayNameForHTML(languageBundle: english) ==
                "No longer active")
        #expect(OrganizationStatus.possiblyInactive.displayNameForHTML(languageBundle: english) ==
                "May no longer be active")
    }

    @Test("The labels are translated into Dutch") func labelsInDutch() {
        let dutch = Bundle.photoClubHubDataModuleForLanguage("nl")
        #expect(OrganizationStatus.inactive.displayNameForHTML(languageBundle: dutch) ==
                "Niet meer actief")
        #expect(OrganizationStatus.possiblyInactive.displayNameForHTML(languageBundle: dutch) ==
                "Mogelijk niet meer actief")
    }

}
