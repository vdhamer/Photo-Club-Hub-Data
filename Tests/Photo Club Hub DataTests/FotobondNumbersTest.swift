//
//  FotobondNumbersTest.swift
//  Photo Club Hub HTML
//
//  Created by Peter van den Hamer on 10/12/2025.
//

import Testing
@testable import Photo_Club_Hub_Data

@Suite
struct FotobondNumbersDisplayTests {

    // MARK: - FotobondClubNumber.display tests

    @Test
    func testValidRegularClubNumberDisplaysCorrectly() {
        let number = FotobondClubNumber(id: 1610)!
        #expect(number.display == "16.10")
    }

    @Test
    func testBoundaryClubZeroConvertsToPersDisplay() {
        let number = FotobondClubNumber(id: 300)!
        #expect(number.display == "03.Pers")
    }

    @Test
    func testLeadingZeroesPreservedForDepartmentAndClub() {
        let number = FotobondClubNumber(id: 301)!
        #expect(number.display == "03.01")
    }

    @Test
    func testInitializerReturnsNilWhenIdIsNil() {
        let id: Int16? = nil
        let number = id.flatMap(FotobondClubNumber.init(id:))
        #expect(number == nil)
    }

    // MARK: - FotobondMemberNumber.display tests

    @Test
    func testRegularMemberNumberDisplaysCorrectly() {
        let number = FotobondMemberNumber(id: 1_610_123)!
        #expect(number.display == "16.10.123")
    }

    @Test
    func testDifferentRegionMemberNumberDisplaysCorrectly() {
        let number = FotobondMemberNumber(id: 304_123)!
        #expect(number.display == "03.04.123")
    }

    @Test
    func testSpecialPersCaseDisplaysCorrectly() {
        let number = FotobondMemberNumber(id: 3_004_321)!
        #expect(number.display == "Pers.4321")
    }

    @Test
    func testMemberInitializerReturnsNilWhenIdIsNil() {
        let id: Int32? = nil
        let number = id.flatMap(FotobondMemberNumber.init(id:))
        #expect(number == nil)
    }
}
