//
//  String+Date.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 20/07/2024.
//

import Foundation // for Date
import RegexBuilder // for Regex

extension String {

    // MARK: - String to date conversion

    // The one date format of all JSON input: a real calendar day, written as YYYY-MM-DD.
    // "2001-12-31" returns 31 Dec 2001.
    // "" returns nil, because that is what SwiftyJSON's stringValue gives for a missing key, which means "no date".
    // Anything else stops a Debug build, including "?", "2026-2-3" and "2026-13-01".
    public func extractDate() -> Date? {
        guard self.isEmpty == false else {
            return nil
        }
        let date: Date?

        if let match = dateMatch() {
            let (_, capturedDate) = match.output
            date = capturedDate
        } else {
            ifDebugFatalError("Illegal date value \"\(self)\": not a real calendar day written as YYYY-MM-DD",
                              file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
            return nil // in release mode, a bad date is returned as nil and the app doesn't stop.
        }

        return date
    }

    // MARK: - Regular expression used locally

    // Matches the entire string, so " 2001-12-31" is not a match.
    // A nil result means that the string is malformed.
    private func dateMatch() -> Regex<(Substring, Date)>.Match? {
        // The date parser below also accepts "2026-2-3" and "26-10-29", so the digits are counted first.
        guard self.wholeMatch(of: #/\d{4}-\d{2}-\d{2}/#) != nil else { return nil }

        let regex = Regex {
            Capture(.date(format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                          locale: Locale.autoupdatingCurrent,
                          timeZone: TimeZone.gmt))
                          // timeZone prevents 2001-12-31 from becoming 2001-12-30 23:00:00 UTC
        }
        return try? regex.wholeMatch(in: self)
    }

}
