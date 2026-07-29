//
//  Photographer+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias PhotographerCoreDataPropertiesSet = NSSet

extension Photographer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photographer> {
        return NSFetchRequest<Photographer>(entityName: "Photographer")
    }

    @NSManaged nonisolated public var bornDT: Date?
    @NSManaged nonisolated public var familyName_: String?
    @NSManaged nonisolated public var givenName_: String?
    @NSManaged nonisolated public var infixName_: String?
    @NSManaged nonisolated public var isDeceased: Bool
    @NSManaged nonisolated public var photographerImage: URL?
    @NSManaged nonisolated public var photographerWebsite: URL?
    @NSManaged nonisolated public var memberships_: NSSet?
    @NSManaged nonisolated public var photographerExpertises_: NSSet?

}

// MARK: Generated accessors for memberships_
extension Photographer {

    @objc(addMemberships_Object:)
    @NSManaged nonisolated public func addToMemberships_(_ value: MemberPortfolio)

    @objc(removeMemberships_Object:)
    @NSManaged nonisolated public func removeFromMemberships_(_ value: MemberPortfolio)

    @objc(addMemberships_:)
    @NSManaged nonisolated public func addToMemberships_(_ values: NSSet)

    @objc(removeMemberships_:)
    @NSManaged nonisolated public func removeFromMemberships_(_ values: NSSet)

}

// MARK: Generated accessors for photographerExpertises_
extension Photographer {

    @objc(addPhotographerExpertises_Object:)
    @NSManaged nonisolated public func addToPhotographerExpertises_(_ value: PhotographerExpertise)

    @objc(removePhotographerExpertises_Object:)
    @NSManaged nonisolated public func removeFromPhotographerExpertises_(_ value: PhotographerExpertise)

    @objc(addPhotographerExpertises_:)
    @NSManaged nonisolated public func addToPhotographerExpertises_(_ values: NSSet)

    @objc(removePhotographerExpertises_:)
    @NSManaged nonisolated public func removeFromPhotographerExpertises_(_ values: NSSet)

}

extension Photographer : Identifiable {

}
