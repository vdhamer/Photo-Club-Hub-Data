//
//  FotobondNumbers.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 03/12/2025.
//

/// These structs are only used in The Netherlands by the Fotobond ("nlSpecific" section of Json input data)

/// A typed wrapper for a Fotobond club identifier.
/// Encapsulates the raw numeric club number as an Int16.
/// Helps prevent confusion with Fotobond club identifiers.
public struct FotobondClubNumber: Equatable {
    /// Raw Fotobond club number (0101...9999). Nil if no valid number found in JSON data.
    let id: Int16?

    public init(id: Int16?) {
        self.id = id
    }

    public var display: String {
        guard id != nil else { return "N/A" }
        return String(format: "%04d", id!) // represent club 301 as "0301"
    }
}

/// A typed wrapper for a Fotobond member identifier.
/// Encapsulates the raw numeric member number as an Int32.
/// Helps prevent confusion with Fotobond member identifiers..
public struct FotobondMemberNumber: Equatable {
    /// Raw Fotobond member number (0...2,147,483,647).
    let id: Int32?

    public init(id: Int32?) {
        self.id = id

    }

    public var display: String {
        guard id != nil else { return "N/A" }
        return String(format: "%07", id!) // represent member 301023 as "0301023"
    }
}
