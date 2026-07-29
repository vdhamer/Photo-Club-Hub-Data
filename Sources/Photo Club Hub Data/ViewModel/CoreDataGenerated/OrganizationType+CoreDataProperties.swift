//
//  OrganizationType+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias OrganizationTypeCoreDataPropertiesSet = NSSet

extension OrganizationType {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OrganizationType> {
        return NSFetchRequest<OrganizationType>(entityName: "OrganizationType")
    }

    @NSManaged nonisolated public var organizationTypeName_: String?
    @NSManaged nonisolated public var unusedProperty: String?
    @NSManaged nonisolated public var organizations_: NSSet?

}

// MARK: Generated accessors for organizations_
extension OrganizationType {

    @objc(addOrganizations_Object:)
    @NSManaged nonisolated public func addToOrganizations_(_ value: Organization)

    @objc(removeOrganizations_Object:)
    @NSManaged nonisolated public func removeFromOrganizations_(_ value: Organization)

    @objc(addOrganizations_:)
    @NSManaged nonisolated public func addToOrganizations_(_ values: NSSet)

    @objc(removeOrganizations_:)
    @NSManaged nonisolated public func removeFromOrganizations_(_ values: NSSet)

}

extension OrganizationType : Identifiable {

}
