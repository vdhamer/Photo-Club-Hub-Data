//
//  String+normalizedTypography.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 08/11/2026.
//

// Replaces typographic apostrophes, quotes, hyphens, dashes and spaces by the plain characters a user types.
// Editors such as WordPress and Apple's Smart Punctuation add the typographic forms, and Apple's geocoder
// writes "'s‑Hertogenbosch" with a non-breaking hyphen. Comparing or searching such strings with plain text
// fails, so organization names, towns, countries, nicknames and remarks, and photographer names are stored
// normalized, and an app normalizes search text the same way before comparing (Data#100). Remarks count because
// the website's visitors search them with the browser's Find. URLs are never normalized: they must stay unaltered.

extension String {

    /// The string with typographic apostrophes, quotes, hyphens, dashes and spaces replaced by plain ones.
    /// Example: "Dia- en Fotoclub ’s‑Gravenzande" (with 2 different types of dash) becomes
    /// "Dia- en Fotoclub 's-Gravenzande" (regular dashes).
    public var normalizedTypography: String {

        // fast return of unmodified strings if they are ASCII only. This should return in almost all cases.
        if self.unicodeScalars.allSatisfy({ $0.isASCII }) { return self }

        var result = String.UnicodeScalarView()             // result starts off empty
        result.reserveCapacity(self.unicodeScalars.count)   // fancy optimization
        for scalar in self.unicodeScalars {
            result.append(Self.plainTypography[scalar] ?? scalar)
        }
        return String(result)
    }

    fileprivate static let plainTypography: [UnicodeScalar: UnicodeScalar] = [
        // apostrophes and single quotes
        "\u{2018}": "'", // left single quotation mark
        "\u{2019}": "'", // right single quotation mark, the usual typographic apostrophe
        "\u{201A}": "'", // single low-9 quotation mark (German?)
        "\u{02BC}": "'", // modifier letter apostrophe
        "\u{2039}": "'", // single left-pointing angle quotation mark
        "\u{203A}": "'", // single right-pointing angle quotation mark

        // double quotes
        "\u{201C}": "\"", // left double quotation mark
        "\u{201D}": "\"", // right double quotation mark
        "\u{201E}": "\"", // double low-9 quotation mark (German?)
        "\u{00AB}": "\"", // left-pointing double angle quotation mark
        "\u{00BB}": "\"", // right-pointing double angle quotation mark

        // hyphens and dashes
        "\u{2010}": "-", // hyphen
        "\u{2011}": "-", // non-breaking hyphen, used by Apple's geocoder
        "\u{2013}": "-", // en dash
        "\u{2014}": "-", // em dash (English?)
        "\u{2212}": "-", // minus sign

        // spaces
        "\u{00A0}": " ", // no-break space
        "\u{202F}": " "  // narrow no-break space
    ]

}
