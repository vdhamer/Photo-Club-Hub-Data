//
//  OrganizationIdPlus.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 10/01/2023.
//

import Foundation

public struct OrganizationIdPlus: Sendable { // PhotoClubID plus non-identifying nickname
    public var id: OrganizationID
    // The nickname isn't part of the identity, but it is a lookup key (Organization.find(nickname:)), it must match
    // between a Level 1 file and the club's Level 2 file, and it ends up in the default vdhamer.com URL. Hand-typed
    // or pasted JSON can write "Witte’s Museum", so it gets the same plain typography as the name (Data#100).
    // A `let`, so it can't be set unnormalized after init.
    public let nickname: String

    public init(id: OrganizationID, nickname: String) { // the one place that sets both properties
        self.id = id
        self.nickname = nickname.normalizedTypography
    }

    public init(fullName: String, // initializer hides PhotoClubId level
                town: String,
                nickname: String) {
        self.init(id: OrganizationID(fullName: fullName, town: town), nickname: nickname)
    }

    // convenience functions
    public var fullName: String { id.fullName }
    public var town: String { id.town }
}

public struct OrganizationID: Hashable, Sendable { // hashable because PhotoClubId is used as dictionary key

    // An organization's identity uses plain apostrophes, quotes and hyphens, whatever the JSON or caller wrote,
    // so "Dia- en Fotoclub ’s-Gravenzande" and "Dia- en Fotoclub 's-Gravenzande" are the same organization.
    // Every lookup and every new Organization goes through this init, and the stored copy goes through the
    // Organization.fullName and .town setters, which normalize too (Data#100).
    //
    // This only governs what is looked up and written from now on. Nothing rewrites rows already in a store, and a
    // store filled before Data#100 can hold "’s-Gravenzande": a plain lookup misses that row and creates a second
    // organization next to it. So introducing this came with a data reset (Settings.userDefaultsKey), which reloads
    // everything through this init. Any later change to what normalizedTypography maps needs a data reset too.
    public init(fullName: String, town: String) {
        self.fullName = fullName.normalizedTypography
        self.town = town.normalizedTypography
    }

    let fullName: String
    let town: String
}
