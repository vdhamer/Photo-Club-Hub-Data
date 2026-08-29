//
//  MemberPortfolio+CoreDataProperties.swift
//  
//
//  Created by Peter van den Hamer on 29/07/2026.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData

public typealias MemberPortfolioCoreDataPropertiesSet = NSSet

extension MemberPortfolio {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MemberPortfolio> {
        return NSFetchRequest<MemberPortfolio>(entityName: "MemberPortfolio")
    }

    @NSManaged nonisolated public var featuredImage: URL?
    @NSManaged nonisolated public var featuredImageThumbnail_: URL?
    @NSManaged nonisolated public var fotobondMemberNumber_: NSNumber?
    @NSManaged nonisolated public var isAdmin: Bool
    @NSManaged nonisolated public var isChairman: Bool
    @NSManaged nonisolated public var isFormerMember: Bool
    @NSManaged nonisolated public var isHonoraryMember: Bool
    @NSManaged nonisolated public var isMentor: Bool
    @NSManaged nonisolated public var isOther: Bool
    @NSManaged nonisolated public var isProspectiveMember: Bool
    @NSManaged nonisolated public var isSecretary: Bool
    @NSManaged nonisolated public var isTreasurer: Bool
    @NSManaged nonisolated public var isViceChairman: Bool
    @NSManaged nonisolated public var level3URL_: URL?
    @NSManaged nonisolated public var membershipEndDate_: Date?
    @NSManaged nonisolated public var membershipStartDate_: Date?
    @NSManaged nonisolated public var removeMember: Bool
    @NSManaged nonisolated public var organization_: Organization?
    @NSManaged nonisolated public var photographer_: Photographer?

}

extension MemberPortfolio : Identifiable {

}
