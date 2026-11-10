//
//  String+normalizedTypographyTest.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 08/11/2026.
//

import Testing
@testable import Photo_Club_Hub_Data

@Suite("Tests String.normalizedTypography (Data#100)") struct NormalizedTypographyTests {

    @Test("Each typographic character becomes its plain form", arguments: [
        ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{201A}", "'"),
        ("\u{02BC}", "'"), ("\u{2039}", "'"), ("\u{203A}", "'"), ("\u{00B4}", "'"),
        ("\u{201C}", "\""), ("\u{201D}", "\""), ("\u{201E}", "\""), ("\u{00AB}", "\""), ("\u{00BB}", "\""),
        ("\u{2010}", "-"), ("\u{2011}", "-"), ("\u{2013}", "-"), ("\u{2014}", "-"), ("\u{2212}", "-"),
        ("\u{00A0}", " "), ("\u{202F}", " ")
    ])
    func eachCharacter(typographic: String, plain: String) {
        #expect("a\(typographic)b".normalizedTypography == "a\(plain)b")
    }

    @Test("Plain text and other non-ASCII characters are left alone") func otherTextUnchanged() {
        #expect("Fotogroep de Gender".normalizedTypography == "Fotogroep de Gender")
        #expect("Köln".normalizedTypography == "Köln")
        #expect("Musée Nicéphore Niépce".normalizedTypography == "Musée Nicéphore Niépce")
        // the same é written as e plus a combining acute accent (U+0301), as some sources do: an accent, kept
        #expect("Muse\u{0301}e".normalizedTypography == "Muse\u{0301}e")
    }

    @Test("A stand-alone acute accent is a mistyped apostrophe") func acuteAccentAsApostrophe() {
        #expect("foto\u{00B4}s".normalizedTypography == "foto's")
    }

    @Test("Names and towns from the data") func namesFromData() {
        #expect("Dia- en Fotoclub ’s-Gravenzande".normalizedTypography == "Dia- en Fotoclub 's-Gravenzande")
        #expect("The Photographers’ Gallery".normalizedTypography == "The Photographers' Gallery")
        #expect("MOMus–Thessaloniki Museum of Photography".normalizedTypography ==
                "MOMus-Thessaloniki Museum of Photography")
        #expect("'s\u{2011}Hertogenbosch".normalizedTypography == "'s-Hertogenbosch") // Apple's geocoder
    }

    @Test("Search text typed with Smart Punctuation matches the stored town") func searchText() {
        let stored = "'s\u{2011}Hertogenbosch".normalizedTypography
        #expect("’s-Hertogenbosch".normalizedTypography == stored) // curly apostrophe from the iOS keyboard
        #expect("'s-Hertogenbosch".normalizedTypography == stored) // plain text
    }

}
