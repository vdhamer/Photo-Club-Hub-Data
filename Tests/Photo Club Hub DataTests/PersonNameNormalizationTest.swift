//
//  PersonNameNormalizationTest.swift
//  Photo Club HubTests
//
//  Created by Peter van den Hamer on 06/09/2026.
//
//  Companion to PersonNameTest.swift, which covers how a PersonName is displayed.
//  This file covers only what it stores, because that is what identifies a person.
//

import Testing
@testable import Photo_Club_Hub_Data

@Suite("Tests that PersonName normalizes the parts it stores") struct PersonNameNormalizationTest {

    // A Photographer is looked up on (givenName, infixName, familyName), so any difference in
    // spelling does not correct a person: it creates a second one that nothing prunes and only a
    // full data reset removes. These cases are the spellings that actually occurred in the data.
    // See vdhamer/Photo-Club-Hub#841 and vdhamer/Photo-Club-Hub-Data#50.

    @Test("A compound family name is written one way, whichever way it arrives",
          arguments: [("Haaren - van de Kaa", "Haaren-van de Kaa"),      // spaced hyphen, fcVeghel
                      ("Sjoerdsma - van der Weide", "Sjoerdsma-van der Weide"),
                      ("Tillaart - van Ham", "Tillaart-van Ham"),
                      ("Heugten-van-Nunen", "Heugten-van Nunen"),        // hyphens for spaces, fgOirschot
                      ("Burgt-van-Dommelen", "Burgt-van Dommelen"),
                      ("Haaren-Van de Kaa", "Haaren-van de Kaa"),        // capitalized second infix
                      ("Haaren-van de Kaa", "Haaren-van de Kaa")])       // already conforming
    func compoundFamilyNameIsNormalized(input: String, expected: String) {
        let name = PersonName(givenName: "Angelique", infixName: "van", familyName: input)
        #expect(name.familyName == expected)
    }

    // Each of these is already correct, for a different reason, and normalization must leave all of
    // them exactly as they are:
    //   "Spuls-Veld"  compound, but its two halves are already joined the "normalized" way
    //   "Jansen"      not compound at all
    //   "D'Eau"       contains an infix, but as the whole family name rather than the second half of
    //                 a compound, so the rule that lowercases a second infix must not reach it
    //   "Op de Beeck" an infix inside a family name with no hyphen anywhere
    @Test("A family name that is already correct is returned unchanged",
          arguments: ["Spuls-Veld", "Jansen", "Doesburg", "D'Eau", "Op de Beeck"])
    func correctFamilyNameIsUntouched(input: String) {
        let name = PersonName(givenName: "Coby", infixName: "", familyName: input)
        #expect(name.familyName == input)
    }

    @Test("The infix is stored lowercase, so Van ... and van ... are one person",
          arguments: [("Van", "van"), ("van", "van"), ("VAN DER", "van der"),
                      ("Van Den", "van den"), (" van  de ", "van de"), ("", "")])
    func infixIsNormalized(input: String, expected: String) {
        let name = PersonName(givenName: "Ben", infixName: input, familyName: "Gerwen")
        #expect(name.infixName == expected)
    }

    @Test("Two spellings of one name produce equal keys") func spellingsAgree() {
        let asWritten = PersonName(givenName: "Margo", infixName: "Van", familyName: "Heugten-van-Nunen")
        let asStored = PersonName(givenName: "Margo", infixName: "van", familyName: "Heugten-van Nunen")
        #expect(asWritten.infixName == asStored.infixName)
        #expect(asWritten.familyName == asStored.familyName)
    }

    // Several infixes end in an apostrophe, and iOS autocorrects a typed one to U+2019 while the
    // reference table uses U+0027. Two forms of one name would be two people, so they converge.
    @Test("A typographic apostrophe is stored as the plain one",
          arguments: [("\u{2019}t", "'t"), ("d\u{2019}", "d'"), ("l\u{02BC}", "l'"), ("'t", "'t")])
    func apostrophesAreNormalized(input: String, expected: String) {
        let name = PersonName(givenName: "Jan", infixName: input, familyName: "Hart")
        #expect(name.infixName == expected)
    }

    @Test("An apostrophe in a family name is normalized too") func familyNameApostrophe() {
        let curly = PersonName(givenName: "Jan", infixName: "", familyName: "D\u{2019}Eau")
        let straight = PersonName(givenName: "Jan", infixName: "", familyName: "D'Eau")
        #expect(curly.familyName == straight.familyName)
    }

    // An infix ending in an apostrophe binds straight to the name after it, so it takes no separator.
    @Test("An apostrophe-bound infix is lowercased after a hyphen",
          arguments: [("Jansen-D'Eau", "Jansen-d'Eau"),
                      ("Jansen-d'Eau", "Jansen-d'Eau"),
                      ("Hart-'T Hooft", "Hart-'t Hooft")])
    func apostropheBoundInfix(input: String, expected: String) {
        let name = PersonName(givenName: "Jan", infixName: "", familyName: input)
        #expect(name.familyName == expected)
    }

    @Test("The synthesized display name uses the normalized parts") func displayNameUsesNormalizedParts() {
        let name = PersonName(givenName: "Margo", infixName: "Van", familyName: "Heugten-van-Nunen")
        #expect(name.fullNameWithoutParenthesizedRole == "Margo van Heugten-van Nunen")
    }

    @Test("A caller-supplied display name is not rewritten") func suppliedDisplayNameIsKept() {
        let name = PersonName(fullNameWithParenthesizedRole: "Margo van Heugten-van Nunen (lid)",
                              givenName: "Margo", infixName: "van", familyName: "Heugten-van Nunen")
        #expect(name.fullNameWithoutParenthesizedRole == "Margo van Heugten-van Nunen")
    }
}
