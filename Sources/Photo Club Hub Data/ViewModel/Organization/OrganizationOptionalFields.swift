//
//  OrganizationOptionalFields.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 26/07/2024.
//

import CoreLocation // for URL
import SwiftyJSON // for JSON struct

// Set of parameters (with their defaults) that are used when creating objects of class Organization.
// Note that Organization is one of the entity types managed by CoreData.
public struct OrganizationOptionalFields {
    var organizationWebsite: URL?
    var wikipedia: URL?
    var level2URL: URL?
    var fotobondClubNumber: FotobondClubNumber?
    var maintainerEmail: String?

    var localizedRemarks: [JSON] // defaults to an empty array instead of to nil

    // For these three, nil means leave the stored values unchanged.
    // findCreateUpdate() has many other callers with default fields, and they must not erase an organization's logbook.
    // Only Level1JsonReader sets them, which is why they aren't in the public init.
    var logEntries: [LogEntryFields]? // in array order: the only order the entries have
    var badWebsites: [String]? // as written in the file, because parsing a URL can rewrite it (Data#63)
    var isFormerOrganization: Bool? // separate from logEntries, because a Level 2 log won't decide this (Data#92)

    public init(organizationWebsite: URL? = nil,
                level2URL: URL? = nil,
                wikipedia: URL? = nil,
                fotobondClubNumber: FotobondClubNumber? = nil,
                maintainerEmail: String? = nil,
                localizedRemarks: [JSON] = []) {
        self.organizationWebsite = organizationWebsite
        self.level2URL = level2URL
        self.wikipedia = wikipedia
        self.fotobondClubNumber = fotobondClubNumber
        self.maintainerEmail = maintainerEmail
        self.localizedRemarks = localizedRemarks
    }
}

// One element of the `logbook` array in a Level 1 file. The values mirror the file, with nil for an absent value.
// The one exception is a malformed date, which a Date can't hold, so such unusable dates are stored as nil.
struct LogEntryFields {
    let date: Date?
    let author: String?
    let text: String?
    let isFormerOrganization: Bool? // nil means that this entry has no intention to change the state
}
