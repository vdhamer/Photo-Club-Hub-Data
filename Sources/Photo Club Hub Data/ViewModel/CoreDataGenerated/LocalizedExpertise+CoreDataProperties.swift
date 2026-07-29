//
//  LocalizedExpertise+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias LocalizedExpertiseCoreDataPropertiesSet = NSSet

extension LocalizedExpertise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalizedExpertise> {
        return NSFetchRequest<LocalizedExpertise>(entityName: "LocalizedExpertise")
    }

    @NSManaged nonisolated public var name_: String?
    @NSManaged nonisolated public var usage: String?
    @NSManaged nonisolated public var expertise_: Expertise?
    @NSManaged nonisolated public var language_: Language?

}

extension LocalizedExpertise : Identifiable {

}
