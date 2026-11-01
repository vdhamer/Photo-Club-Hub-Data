//
//  LogEntry.swift
//  Photo Club Hub
//
//  Created by Claude Code (guided by Peter van den Hamer) on 31/10/2026.
//

import CoreData // for NSManagedObject

// One entry in an organization's logbook: one element of the `logbook` array in a Level 1 JSON file (Data#91).
// `originalDataSourceLevel` is the level of the file where the entry was first found. Copying never changes it.
// It is always 1 until Level 2 files can hold a logbook (Data#92).
// `position` is the entry's index in that file's array, so it is only unique per organization and level.
extension LogEntry { // expose computed properties (some related to handling optionals)

    @available(*, unavailable)
    convenience init() {
        fatalError("init() is not available. Log entries are created when a Level 1 file is loaded.")
    }

    // MARK: - getters (setting is done when a Level 1 file is loaded)

    public var organization: Organization { // getter
        if let organization = organization_ {
            return organization
        } else {
            fatalError("Error because organization is nil") // something is fundamentally wrong if this happens
        }
    }

    // The calendar day on which the entry was written, held as midnight GMT, like membership dates and `bornDT`.
    // So format it in GMT when displaying it, to avoid it showing the previous day in the Americas (West of GMT).
    // A malformed JSON date stops a Debug build (see `extractDate()`).
    // Otherwise, a missing or malformed date doesn't drop the entry, because that entry may hold the isFormerClub key.
    // The fallback is far enough from any real date to be noticed by someone reading the logbook.
    public var date: Date {
        date_ ?? Date.distantPast
    }

    // `author` is required in a Level 1 LogEntry block, and not allowed to be blank.
    // A file that breaks that rule gets a placeholder here, so someone reading the logbook can see the problem.
    // An empty string would look deliberate.
    // The stored value mirrors the file (Data#63), so it is nil if the key is missing, and blank if the file says so.
    // That's why nonBlank() checks for both, instead of a plain `author_ ?? "Author?"`.
    public var author: String {
        nonBlank(author_, otherwise: "Author?")
    }

    // Same rule as for `author`: a missing or blank value isn't allowed, and is displayed as "Text?".
    public var text: String {
        nonBlank(text_, otherwise: "Text?")
    }

    private func nonBlank(_ value: String?, otherwise placeholder: String) -> String {
        guard let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            else { return placeholder }
        return value
    }

    // nil means that this logEntry has no intention to change whether the organization is "former".
    // So this var only converts a Core Data representation to a standard Swift optional.
    public var isFormerOrganization: Bool? {
        isFormerOrganization_?.boolValue
    }

}
