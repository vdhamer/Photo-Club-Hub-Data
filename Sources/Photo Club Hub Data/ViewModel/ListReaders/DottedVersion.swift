//
//  DottedVersion.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 20/11/2026.
//

/// A dotted version number such as "3.9.0" or "3.11", compared part by part as numbers (Data#107).
///
/// Used to compare this package's own version (`PhotoClubHubDataVersion.semver`) with the
/// `minimumDataPackageVersion` that a Level 1 file asks for. A text comparison would get "3.9.0" and "3.11.0" the
/// wrong way round, so the parts have to be compared as numbers.
///
/// A part missing at the end counts as zero: "3.9" equals "3.9.0". Trailing zeros are therefore dropped once, at
/// initialization, so that both of those become [3, 9]. After that, `<` can be `lexicographicallyPrecedes` and `==`
/// can be the one Swift synthesizes from `parts`. Without the trimming, both would get "3.9" against "3.9.0" wrong:
/// `lexicographicallyPrecedes` ranks a prefix lower, so [3, 9] < [3, 9, 0], and the synthesized `==` calls them
/// unequal. A file asking for "3.9" would then be reported as asking for more than a 3.9.0 build. Padding the shorter
/// version with zeros on every comparison would work too, but would need a hand-written `==` as well.
///
/// Only digits and dots are accepted. A pre-release suffix such as "3.9.0-beta" is not a version a file should ask
/// for, so it fails to parse and the caller reports the file instead of guessing. An empty part ("3..0", "3.") fails
/// too: a part counts as zero only when it is left out, dot and all. So does a part with a leading zero ("3.09"):
/// no version is written that way, so it is more likely a typo than a deliberate "3.9".
struct DottedVersion: Sendable {

    private let parts: [Int] // never ends in a zero, so "3.9.0" and "3.9" have the same parts (see above)

    /// Returns nil unless `text` is one or more non-negative whole numbers without leading zeros, separated by
    /// single dots.
    init?(_ text: String) {
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false) // keeps "3..0" and "3." invalid
        let numbers: [Int] = pieces.compactMap { piece in
            // not `Int(piece)` alone: that also accepts a sign ("+3", "-3"), which no version has
            guard piece.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
            guard piece == "0" || piece.first != "0" else { return nil } // "0" is a part, "09" and "00" are not
            return Int(piece)
        }
        // a piece was empty, not a number, had a leading zero, or exceeded Int.max (`Int(piece)` returns nil)
        guard numbers.count == pieces.count else { return nil }

        var trimmed = numbers
        while trimmed.last == 0 { trimmed.removeLast() }
        parts = trimmed
    }
}

extension DottedVersion: Comparable {

    static func < (lhs: DottedVersion, rhs: DottedVersion) -> Bool {
        lhs.parts.lexicographicallyPrecedes(rhs.parts)
    }

}
