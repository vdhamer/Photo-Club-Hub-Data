//
//  DottedVersionTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 20/11/2026.
//

import Testing // for macros like @Test
@testable import Photo_Club_Hub_Data

/// How `DottedVersion` reads and compares the versions in a Level 1 header (Data#107).
@Suite("Tests the dotted version numbers of minimumDataPackageVersion") struct DottedVersionTests {

    @Test("Versions are compared part by part as numbers, not as text",
          arguments: [("3.9.0", "3.11.0"), // as text, "3.11" would come first
                      ("3.9.9", "3.10.0"),
                      ("2.99.99", "3.0.0"),
                      ("3.9", "3.9.1"), // a missing part counts as zero
                      ("3", "3.0.1")])
    func ordersNumerically(lower: String, higher: String) throws {
        let lowerVersion = try #require(DottedVersion(lower))
        let higherVersion = try #require(DottedVersion(higher))
        #expect(lowerVersion < higherVersion)
        #expect((higherVersion < lowerVersion) == false)
    }

    @Test("A missing trailing part counts as zero, so these versions are equal",
          arguments: [("3.9", "3.9.0"),
                      ("3", "3.0.0"),
                      ("3.9.0", "3.9.0.0"),
                      ("0.9", "0.9.0")])
    func equalsWithTrailingZeros(first: String, second: String) throws {
        let firstVersion = try #require(DottedVersion(first))
        let secondVersion = try #require(DottedVersion(second))
        #expect(firstVersion == secondVersion)
        #expect((firstVersion < secondVersion) == false)
        #expect((secondVersion < firstVersion) == false)
    }

    @Test("Text that is not a dotted number is not a version",
          arguments: ["", "three", "3.x", "3..0", "3.", ".3", "-3.0", "+3.0", " 3.9.0", "3.9.0 ", "3.9.0-beta",
                      "3,9,0", "99999999999999999999.0", "03.9.0", "3.09", "3.00", "3.9.00"])
    func rejectsNonVersions(text: String) {
        #expect(DottedVersion(text) == nil)
    }

    @Test("The package's own version is a version")
    func ownVersionParses() {
        #expect(DottedVersion(PhotoClubHubDataVersion.semver) != nil)
    }
}
