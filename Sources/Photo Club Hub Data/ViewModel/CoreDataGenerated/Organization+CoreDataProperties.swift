//
//  Organization+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias OrganizationCoreDataPropertiesSet = NSSet

extension Organization {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Organization> {
        return NSFetchRequest<Organization>(entityName: "Organization")
    }

    @NSManaged nonisolated public var fotobondClubNumber_: NSNumber?
    @NSManaged nonisolated public var fullName_: String?
    @NSManaged nonisolated public var isMapScrollLocked: Bool
    @NSManaged nonisolated public var latitude_: Double
    @NSManaged nonisolated public var level2URL_: URL?
    @NSManaged nonisolated public var longitude_: Double
    @NSManaged nonisolated public var maintainerEmail_: String?
    @NSManaged nonisolated public var nickName_: String?
    @NSManaged nonisolated public var organizationWebsite: URL?
    @NSManaged nonisolated public var pinned: Bool
    @NSManaged nonisolated public var removeOrganization: Bool
    @NSManaged nonisolated public var town_: String?
    @NSManaged nonisolated public var wikipedia: URL?
    @NSManaged nonisolated public var localizedAddresses_: NSSet?
    @NSManaged nonisolated public var localizedRemarks_: NSSet?
    @NSManaged nonisolated public var members_: NSSet?
    @NSManaged nonisolated public var organizationType_: OrganizationType?

}

// MARK: Generated accessors for localizedAddresses_
extension Organization {

    @objc(addLocalizedAddresses_Object:)
    @NSManaged nonisolated public func addToLocalizedAddresses_(_ value: LocalizedAddress)

    @objc(removeLocalizedAddresses_Object:)
    @NSManaged nonisolated public func removeFromLocalizedAddresses_(_ value: LocalizedAddress)

    @objc(addLocalizedAddresses_:)
    @NSManaged nonisolated public func addToLocalizedAddresses_(_ values: NSSet)

    @objc(removeLocalizedAddresses_:)
    @NSManaged nonisolated public func removeFromLocalizedAddresses_(_ values: NSSet)

}

// MARK: Generated accessors for localizedRemarks_
extension Organization {

    @objc(addLocalizedRemarks_Object:)
    @NSManaged nonisolated public func addToLocalizedRemarks_(_ value: LocalizedRemark)

    @objc(removeLocalizedRemarks_Object:)
    @NSManaged nonisolated public func removeFromLocalizedRemarks_(_ value: LocalizedRemark)

    @objc(addLocalizedRemarks_:)
    @NSManaged nonisolated public func addToLocalizedRemarks_(_ values: NSSet)

    @objc(removeLocalizedRemarks_:)
    @NSManaged nonisolated public func removeFromLocalizedRemarks_(_ values: NSSet)

}

// MARK: Generated accessors for members_
extension Organization {

    @objc(addMembers_Object:)
    @NSManaged nonisolated public func addToMembers_(_ value: MemberPortfolio)

    @objc(removeMembers_Object:)
    @NSManaged nonisolated public func removeFromMembers_(_ value: MemberPortfolio)

    @objc(addMembers_:)
    @NSManaged nonisolated public func addToMembers_(_ values: NSSet)

    @objc(removeMembers_:)
    @NSManaged nonisolated public func removeFromMembers_(_ values: NSSet)

}

extension Organization : Identifiable {

}
