//
//  Level1SourceTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 20/11/2026.
//

import Testing      // for macros like @Test
@testable import Photo_Club_Hub_Data
import Foundation   // for URL

/// Which last path components does `Level1Source` accept as a Level 1 file name, and what does it make of them
/// (Data#107). The cases are the rows of the table in that ticket. The leading, doubled and trailing dot are
/// separate cases because each is a position that an implementation can get right while missing another.
@Suite("Tests which Level 1 file names are accepted") struct Level1SourceTests {

    private static let directory = "https://raw.githubusercontent.com/vdhamer/Photo-Club-Hub-Data/main/JSON/"

    @Test("A valid file name gives the part before .level1.json",
          arguments: [("clubsNL.level1.json", "clubsNL"),
                      ("afd16.NL.clubs.level1.json", "afd16.NL.clubs"),
                      ("clubsNL.Level1.JSON", "clubsNL"), // suffix in any letter case
                      ("clubsBE-Antwerpen.level1.json", "clubsBE-Antwerpen")])
    func acceptsValidNames(lastPathComponent: String, expectedFileName: String) throws {
        let source = try Level1Source(urlString: Self.directory + lastPathComponent)
        #expect(source.fileName == expectedFileName)
    }

    @Test("An invalid file name is rejected",
          arguments: [".level1.json",               // nothing before the suffix
                      ".clubs.level1.json",         // starts with a dot
                      "afd16..clubs.level1.json",   // two dots in a row
                      "clubs..level1.json",         // ends with a dot
                      "clubsNL.json",               // no .level1.json
                      "clubsNL.level1",             // no .json
                      "clubsNL.level1.json.bak",    // text after .json
                      "museums"])                   // no .level1.json
    func rejectsInvalidNames(lastPathComponent: String) {
        #expect {
            try Level1Source(urlString: Self.directory + lastPathComponent)
        } throws: { error in
            guard case Level1URLError.notALevel1FileName = error else { return false }
            return true
        }
    }

    // The custom Level 1 root reaches `LevelLoader` as a bare URL, without going through the initializer above.
    @Test("A custom root gets the same name, or a fallback when it is not a Level 1 file name",
          arguments: [("afd16.NL.clubs.level1.json", "afd16.NL.clubs"),
                      ("root.level1.json", "root"),
                      ("my.photo.clubs.json", "customLevel1Root"),
                      (".level1.json", "customLevel1Root")])
    func namesCustomRoot(lastPathComponent: String, expectedFileName: String) throws {
        let url = try #require(URL(string: "https://example.org/mine/" + lastPathComponent))
        #expect(Level1Source.fileName(of: url) == expectedFileName)
    }
}
