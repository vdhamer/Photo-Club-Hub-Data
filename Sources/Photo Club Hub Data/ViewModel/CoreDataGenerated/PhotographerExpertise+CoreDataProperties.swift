//
//  PhotographerExpertise+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias PhotographerExpertiseCoreDataPropertiesSet = NSSet

extension PhotographerExpertise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PhotographerExpertise> {
        return NSFetchRequest<PhotographerExpertise>(entityName: "PhotographerExpertise")
    }

    @NSManaged nonisolated public var expertise_: Expertise?
    @NSManaged nonisolated public var photographer_: Photographer?

}

extension PhotographerExpertise : Identifiable {

}
