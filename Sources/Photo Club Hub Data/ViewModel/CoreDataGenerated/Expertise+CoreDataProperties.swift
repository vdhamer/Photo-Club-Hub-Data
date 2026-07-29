//
//  Expertise+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias ExpertiseCoreDataPropertiesSet = NSSet

extension Expertise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Expertise> {
        return NSFetchRequest<Expertise>(entityName: "Expertise")
    }

    @NSManaged nonisolated public var id_: String?
    @NSManaged nonisolated public var isSupported: Bool
    @NSManaged nonisolated public var localizedExpertises_: NSSet?
    @NSManaged nonisolated public var photographerExpertises_: NSSet?

}

// MARK: Generated accessors for localizedExpertises_
extension Expertise {

    @objc(addLocalizedExpertises_Object:)
    @NSManaged nonisolated public func addToLocalizedExpertises_(_ value: LocalizedExpertise)

    @objc(removeLocalizedExpertises_Object:)
    @NSManaged nonisolated public func removeFromLocalizedExpertises_(_ value: LocalizedExpertise)

    @objc(addLocalizedExpertises_:)
    @NSManaged nonisolated public func addToLocalizedExpertises_(_ values: NSSet)

    @objc(removeLocalizedExpertises_:)
    @NSManaged nonisolated public func removeFromLocalizedExpertises_(_ values: NSSet)

}

// MARK: Generated accessors for photographerExpertises_
extension Expertise {

    @objc(addPhotographerExpertises_Object:)
    @NSManaged nonisolated public func addToPhotographerExpertises_(_ value: PhotographerExpertise)

    @objc(removePhotographerExpertises_Object:)
    @NSManaged nonisolated public func removeFromPhotographerExpertises_(_ value: PhotographerExpertise)

    @objc(addPhotographerExpertises_:)
    @NSManaged nonisolated public func addToPhotographerExpertises_(_ values: NSSet)

    @objc(removePhotographerExpertises_:)
    @NSManaged nonisolated public func removeFromPhotographerExpertises_(_ values: NSSet)

}

extension Expertise : Identifiable {

}
