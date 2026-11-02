//
//  URL+canonicalStringTest.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 01/11/2026.
//

import Foundation
import Testing
@testable import Photo_Club_Hub_Data

@Suite
struct CanonicalStringTests {
    @Test
    func spellingsOfOneWebsiteGetTheSameString() throws {
        let spellings = ["https://www.fcDeGender.nl/",
                         "https://www.fcdegender.nl",
                         "http://fcdegender.nl",
                         "www.fcDeGender.nl",
                         "HTTPS://WWW.FCDEGENDER.NL//"]
        for spelling in spellings {
            #expect(try #require(URL(string: spelling)).canonicalString == "fcdegender.nl", "\(spelling)")
        }
    }

    @Test
    func onlyTheDomainIsLowercased() throws {
        let url = try #require(URL(string: "https://WWW.FcDeGender.nl/Members/Jan?Tab=Info"))
        #expect(url.canonicalString == "fcdegender.nl/Members/Jan?Tab=Info")
    }

    @Test
    func standardNormalizationIsApplied() throws {
        let spellings = ["https://fcdegender.nl:443/#top",
                         "https://fcdegender.nl/a/../",
                         "https://FCDEGENDER.nl/./"]
        for spelling in spellings {
            #expect(try #require(URL(string: spelling)).canonicalString == "fcdegender.nl", "\(spelling)")
        }
        let encoded = try #require(URL(string: "https://fcdegender.nl/caf%C3%A9"))
        let unencoded = try #require(URL(string: "https://fcdegender.nl/café"))
        #expect(encoded.canonicalString == unencoded.canonicalString)
    }

    @Test("Unparseable URL falls back to trimmed, lowercased text and fires diagnostic", .usesIfDebugFatalErrorSpy)
    func unparseableUrlFallsBack() throws {
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        let url = try #require(URL(string: "https://FcDeGender.nl:99999/Members/")) // port 99999 out of range

        #expect(url.canonicalString == "https://fcdegender.nl:99999/members")
        #expect(spy.messages.contains { $0.contains("cannot parse") }) // a count could include unrelated tests (Data#1)
    }

    @Test
    func differentWebsitesStayDifferent() throws {
        let members = try #require(URL(string: "https://fcdegender.nl/members"))
        let home = try #require(URL(string: "https://fcdegender.nl"))
        let other = try #require(URL(string: "https://www2.fcdegender.nl"))
        #expect(members.canonicalString != home.canonicalString)
        #expect(other.canonicalString != home.canonicalString)
    }
}
