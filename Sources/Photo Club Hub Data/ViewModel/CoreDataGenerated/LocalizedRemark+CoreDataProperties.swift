//
//  LocalizedRemark+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias LocalizedRemarkCoreDataPropertiesSet = NSSet

extension LocalizedRemark {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalizedRemark> {
        return NSFetchRequest<LocalizedRemark>(entityName: "LocalizedRemark")
    }

    @NSManaged nonisolated public var localizedString: String?
    @NSManaged nonisolated public var language_: Language?
    @NSManaged nonisolated public var organization_: Organization?

}

extension LocalizedRemark : Identifiable {

}
