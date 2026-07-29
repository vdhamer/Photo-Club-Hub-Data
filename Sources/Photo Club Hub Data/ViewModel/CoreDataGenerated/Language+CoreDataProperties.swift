//
//  Language+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias LanguageCoreDataPropertiesSet = NSSet

extension Language {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Language> {
        return NSFetchRequest<Language>(entityName: "Language")
    }

    @NSManaged nonisolated public var isoCode_: String?
    @NSManaged nonisolated public var languageNameEN_: String?
    @NSManaged nonisolated public var localizedAddresses_: NSSet?
    @NSManaged nonisolated public var localizedExpertises_: NSSet?
    @NSManaged nonisolated public var localizedRemarks_: NSSet?

}

// MARK: Generated accessors for localizedAddresses_
extension Language {

    @objc(addLocalizedAddresses_Object:)
    @NSManaged nonisolated public func addToLocalizedAddresses_(_ value: LocalizedAddress)

    @objc(removeLocalizedAddresses_Object:)
    @NSManaged nonisolated public func removeFromLocalizedAddresses_(_ value: LocalizedAddress)

    @objc(addLocalizedAddresses_:)
    @NSManaged nonisolated public func addToLocalizedAddresses_(_ values: NSSet)

    @objc(removeLocalizedAddresses_:)
    @NSManaged nonisolated public func removeFromLocalizedAddresses_(_ values: NSSet)

}

// MARK: Generated accessors for localizedExpertises_
extension Language {

    @objc(addLocalizedExpertises_Object:)
    @NSManaged nonisolated public func addToLocalizedExpertises_(_ value: LocalizedExpertise)

    @objc(removeLocalizedExpertises_Object:)
    @NSManaged nonisolated public func removeFromLocalizedExpertises_(_ value: LocalizedExpertise)

    @objc(addLocalizedExpertises_:)
    @NSManaged nonisolated public func addToLocalizedExpertises_(_ values: NSSet)

    @objc(removeLocalizedExpertises_:)
    @NSManaged nonisolated public func removeFromLocalizedExpertises_(_ values: NSSet)

}

// MARK: Generated accessors for localizedRemarks_
extension Language {

    @objc(addLocalizedRemarks_Object:)
    @NSManaged nonisolated public func addToLocalizedRemarks_(_ value: LocalizedRemark)

    @objc(removeLocalizedRemarks_Object:)
    @NSManaged nonisolated public func removeFromLocalizedRemarks_(_ value: LocalizedRemark)

    @objc(addLocalizedRemarks_:)
    @NSManaged nonisolated public func addToLocalizedRemarks_(_ values: NSSet)

    @objc(removeLocalizedRemarks_:)
    @NSManaged nonisolated public func removeFromLocalizedRemarks_(_ values: NSSet)

}

extension Language : Identifiable {

}
