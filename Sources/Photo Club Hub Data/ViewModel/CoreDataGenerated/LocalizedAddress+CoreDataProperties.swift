//
//  LocalizedAddress+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias LocalizedAddressCoreDataPropertiesSet = NSSet

extension LocalizedAddress {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalizedAddress> {
        return NSFetchRequest<LocalizedAddress>(entityName: "LocalizedAddress")
    }

    @NSManaged nonisolated public var localizedCountry_: String?
    @NSManaged nonisolated public var localizedTown_: String?
    @NSManaged nonisolated public var prevLatitude: Double
    @NSManaged nonisolated public var prevLongitude: Double
    @NSManaged nonisolated public var language_: Language?
    @NSManaged nonisolated public var organization_: Organization?

}

extension LocalizedAddress : Identifiable {

}
