//
//  PersonName.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 23/09/2023.
//

import RegexBuilder // for Regex { }

/// A person's name, split into its constituent parts and optionally carrying a club role.
///
/// Dutch names often contain an infix (a "tussenvoegsel" such as "van" or "de") that sits
/// between the given name and the family name, so it is stored separately rather than being
/// folded into the family name. The display string may also include a parenthesized role
/// (e.g. "(lid)") that callers can strip when only the bare name is needed.
public struct PersonName {
    /// The display name, including any parenthesized role, e.g. "John Doe (lid)" or "Jan van Doesburg".
    var fullNameWithParenthesizedRole: String
    /// The given (first) name, e.g. "John" or "Jan".
    public let givenName: String
    /// The infix ("tussenvoegsel"), e.g. "" or "van" or "op de". Uses an empty String when the name has no infix.
    public let infixName: String
    /// The family (last) name, e.g. "Doe" or "Doesburg".
    public let familyName: String
    /// The display name with any trailing parenthesized role removed, e.g.
    /// "Bart van Stekelenburg (lid)" becomes "Bart van Stekelenburg".
    var fullNameWithoutParenthesizedRole: String {
        return removeParenthesizedRole(fullNameWithParenthesizedRole: fullNameWithParenthesizedRole)
    }

    /// Creates a PersonName from its parts.
    ///
    /// - Parameters:
    ///   - fullNameWithParenthesizedRole: The display name including any role. When `nil`, it is
    ///     synthesized from the other parameters as "given [infix ]family" with no role.
    ///   - givenName: The given (first) name.
    ///   - infixName: The infix ("tussenvoegsel"); pass an empty string when there is none.
    ///   - familyName: The family (last) name.
    public init(fullNameWithParenthesizedRole: String? = nil,
                givenName: String,
                infixName: String,
                familyName: String) {
        // Normalized before being stored: see `normalized(infixName:)` and `normalized(familyName:)`.
        let infix = Self.normalized(infixName: infixName)
        let family = Self.normalized(familyName: familyName)

        // if fullNameWithParenthesizedRole not provide, synthesize it without a  role
        self.fullNameWithParenthesizedRole = fullNameWithParenthesizedRole != nil ? fullNameWithParenthesizedRole! :
                                             givenName + " " + (infix.isEmpty ? "" : "\(infix) ") + family
        self.givenName = givenName
        self.infixName = infix
        self.familyName = family
    }

    /// Every "voorvoegsel" the Dutch government recognizes, longest first so that "van der" is not
    /// matched as "van" with a stray "der" left behind.
    ///
    /// Source: RvIG, Landelijke Tabellen BRP, **Tabel 36 Voorvoegselstabel**, dated 01-12-2004 and
    /// never revised since — tables 36 and 38 are the two the register declares fixed. Retrieved
    /// 6 September 2026 from https://publicaties.rvig.nl/media/13287/download and lowercased. It
    /// covers the German forms ("von", "zu", "auf", "aus") and the Romance ones ("de la", "du",
    /// "della", "dos"), so it does not need immediate revisiting if data arrives from nearby countries.
    ///
    /// It replaced a hand-written list, which had already proved the point by omitting "du" while
    /// a member with that infix sat in the data.
    ///
    /// Being long is harmless here. This list only decides where a space is restored after a hyphen,
    /// so an entry that never occurs costs nothing, while a missing one leaves a name unnormalized
    /// and can therefore let one person exist twice. That is the opposite of the trade-off facing the
    /// scavenger, which uses a similar list to *detect* infixes in running text: there every extra
    /// entry is another way to read "Burgemeester van Veldhoven" as a person, so its list must stay
    /// short and hand-picked. The two are not the same list and should not be merged.
    private static let compoundInfixes = ["de van der", "uijt te de", "van van de", "voor in 't", "de die le",
                                          "onder den", "onder het", "uit te de", "van de l'", "voor in t",
                                          "boven d'", "onder 't", "onder de", "over den", "over het", "uijt den",
                                          "uijt ten", "van de l", "voor den", "aan den", "aan der", "aan het",
                                          "auf dem", "auf den", "auf der", "auf ter", "aus dem", "aus den",
                                          "aus der", "bij den", "bij het", "boven d", "onder t", "over 't",
                                          "over de", "uijt 't", "uijt de", "uit den", "uit het", "uit ten",
                                          "van den", "van der", "van gen", "van het", "van ter", "von dem",
                                          "von den", "von der", "voor 't", "voor de", "vor der", "aan 't", "aan de",
                                          "aus 'm", "bij 't", "bij de", "de die", "de las", "die le", "in den",
                                          "in der", "in het", "op den", "op der", "op gen", "op het", "op ten",
                                          "over t", "uit 't", "uit de", "van 't", "van de", "van la", "von 't",
                                          "aan t", "am de", "aus m", "bij t", "dalla", "de l'", "de la", "de le",
                                          "degli", "della", "in 't", "in de", "onder", "op 't", "op de", "uit t",
                                          "unter", "van t", "von t", "dal'", "de l", "deca", "in t", "op t", "over",
                                          "thoe", "thor", "uijt", "voor", "aan", "auf", "aus", "ben", "bij", "bin",
                                          "dal", "das", "dei", "del", "den", "der", "des", "don", "dos", "het",
                                          "las", "les", "los", "ten", "ter", "tho", "toe", "tot", "uit", "van",
                                          "ver", "vom", "von", "vor", "zum", "zur", "'s", "'t", "af", "al", "am",
                                          "d'", "da", "de", "di", "do", "du", "el", "im", "in", "l'", "la", "le",
                                          "lo", "of", "op", "s'", "te", "to", "zu", "a", "d", "i", "l", "s", "t"]

    /// Lowercases the infix, because `infixName` is part of the key a `Photographer` is looked up by.
    ///
    /// "Van" and "van" would otherwise be two different people, and the second one arrives silently:
    /// nothing reports it, and only a full data reset removes the first. Flemish names that fuse the
    /// infix onto the surname, such as "Vanantwerpen", are family names rather than infixes and never
    /// reach this field.
    private static func normalized(infixName: String) -> String {
        straightApostrophes(in: infixName)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
    }

    /// Rewrites typographic apostrophes as the plain ASCII one, U+0027.
    ///
    /// Several infixes end in an apostrophe: "'t", "d'", "l'", "s'". iOS and macOS autocorrect a typed
    /// apostrophe to U+2019, websites use it freely, and the RvIG table uses U+0027, so the same name
    /// arrives in at least two forms. Since the name *is* the identity key, those forms would be two
    /// different people. Picking one is what makes them one person; U+0027 is the one, because that is
    /// what the reference table and a keyboard produce.
    private static func straightApostrophes(in text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'")   // right single quotation mark
            .replacingOccurrences(of: "\u{02BC}", with: "'")   // modifier letter apostrophe
            .replacingOccurrences(of: "\u{00B4}", with: "'")   // acute accent, a common mistyping
    }

    /// Writes a compound (usually married) family name in a standard way, whatever way it arrived.
    ///
    /// One hyphen joins the two family names with no spaces around it, and the second name keeps the
    /// space before its own infix, so "Haaren - van de Kaa", "Haaren-van-de-Kaa" and "Haaren-Van de Kaa"
    /// all become "Haaren-van de Kaa". Seven such names existed in the data (Sep 26)  and no two were written
    /// alike, which cost a forced data reset to correct: see vdhamer/Photo-Club-Hub#841.
    ///
    /// This tidies parts that have already been separated. Deciding *where* the infix is in a name read
    /// as one string is a different problem, and belongs to whatever produced the parts: a person filling
    /// in a form, or the scavenger providing a suggested name by reading a website.
    private static func normalized(familyName: String) -> String {
        // one hyphen, no spaces around it
        var result = straightApostrophes(in: familyName)
            .replacingOccurrences(of: #"\s*-\s*"#, with: "-", options: .regularExpression)
        // the second family name keeps the space before its own infix, and that infix is lowercased,
        // so "Heugten-Van-Nunen" becomes "Heugten-van Nunen"
        for infix in compoundInfixes {
            // An infix ending in an apostrophe binds straight to the name that follows it, as in
            // "Jansen-d'Eau", so it takes no separator. Every other infix requires one, or "-de"
            // would match inside a family name that merely starts with those letters.
            let bindsDirectly = infix.hasSuffix("'")
            result = result.replacingOccurrences(of: bindsDirectly ? "-\(infix)" : "-\(infix)[- ]",
                                                 with: bindsDirectly ? "-\(infix)" : "-\(infix) ",
                                                 options: [.regularExpression, .caseInsensitive])
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Strips a trailing " (role)" suffix from a full name, leaving the name itself untouched.
    /// Returns the input unchanged if it contains no parenthesized role.
    @available(macOS 13.0, *)
    private func removeParenthesizedRole(fullNameWithParenthesizedRole: String) -> String {
        // "José Daniëls" → "José Daniëls" - former member
        // "Bart van Stekelenburg (lid)" → "Bart van Stekelenburg" - member
        // "Zoë Aspirant (aspirantlid)" → "Zoë Aspirant" - aspiring member
        // "Hans Zoete (mentor)" → "Hans Zoete" - coach
        let regex = Regex {
            Capture {
                OneOrMore(.any, .reluctant)
            } transform: { fullName in String(fullName) }
            Optionally {
                " (" // e.g. " (lid)"
                OneOrMore(.any)
            }
        }

        if let match = try? regex.wholeMatch(in: fullNameWithParenthesizedRole) {
            let (_, fullName) = match.output
            return fullName
        } else {
            ifDebugFatalError("Error: problem performing removeParenthesizedRole(\(fullNameWithParenthesizedRole))")
            return fullNameWithParenthesizedRole
        }
    }
}
