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

    // "2001-12-31" returns Dec 31st 2001
    // "?" returns nil without triggering ifDebugFatalError()
    public func extractDate() -> Date? {
        guard self.isEmpty == false, self != "?" else {
            return nil
        }
        let date: Date?

        if let match = dateMatch() {
            let (_, capturedDate) = match.output
            date = capturedDate
        } else {
            ifDebugFatalError("Failed to decode date from \(self) because RegEx didn't trigger",
                              file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
            return nil // in release mode, a bad date is returned as nil and the app doesn't stop.
        }

        return date
    }

    // Same as extractDate(), except that a malformed date doesn't trigger ifDebugFatalError: it simply returns nil.
    // For data where a bad date is a reason to warn, but not to stop: a log entry must survive a date issue (Data#91).
    func extractDateQuietly() -> Date? {
        dateMatch()?.output.1
    }

    // MARK: - Regular expression used locally

    // Matches the entire string, so " 2001-12-31" is not a match.
    // A nil result means that the string is malformed.
    private func dateMatch() -> Regex<(Substring, Date)>.Match? {
        let regex = Regex {
            Capture(.date(format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                          locale: Locale.autoupdatingCurrent,
                          timeZone: TimeZone.gmt))
                          // timeZone prevents 2001-12-31 from becoming 2001-12-30 23:00:00 UTC
        }
        return try? regex.wholeMatch(in: self)
    }

}
