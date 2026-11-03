//
//  String+DateTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 20/07/2026.
//

import Foundation // for Calendar, TimeZone
import Testing
@testable import Photo_Club_Hub_Data

@Suite("Tests String.extractDate()") struct StringExtractDateTests {

    // The test verifies that extractDate() is timezone-consistent (almost certainly by parsing in UTC/GMT), so a
    // date-only string always round-trips back to the same calendar day regardless of the device's locale.
    @Test("Valid ISO date returns correct Date without timezone drift") func validDateNoTimezoneDrift() throws {
        let date = try #require("2001-12-31".extractDate())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "GMT")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2001)
        #expect(components.month == 12)
        #expect(components.day == 31)
    }

    @Test("Empty string returns nil") func emptyStringReturnsNil() {
        #expect("".extractDate() == nil)
    }

    @Test("Malformed input returns nil and fires diagnostic", .usesIfDebugFatalErrorSpy)
    func malformedInputReturnsNil() {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        let result = "not-a-date".extractDate()

        #expect(result == nil)
        #expect(spy.messages.contains { $0.contains("not-a-date") }) // a count could include unrelated tests (Data#1)
    }

    // The date parser alone would accept the first two, so these check that the digits are counted too.
    // The last two aren't real calendar days.
    @Test("A date not written as YYYY-MM-DD, or not a real date, is malformed", .usesIfDebugFatalErrorSpy)
    func looseOrImpossibleDateIsMalformed() {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        for text in ["2026-2-3", "26-10-29", "2026-13-01", "2026-02-29"] {
            #expect(text.extractDate() == nil, "\(text)")
            #expect(spy.messages.contains { $0.contains("Illegal date value \"\(text)\"") }, "\(text)")
        }
    }

    // "?" once meant "unknown date". Nothing uses it, and a missing key already means that.
    @Test("A question mark as a value is illegal", .usesIfDebugFatalErrorSpy)
    func questionMarkIsMalformed() {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        #expect("?".extractDate() == nil)
        #expect(spy.messages.contains { $0.contains("Illegal date value \"?\"") })
    }

}
