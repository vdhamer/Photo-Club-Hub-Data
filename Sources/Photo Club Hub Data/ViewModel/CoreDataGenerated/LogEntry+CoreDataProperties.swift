//
//  LogEntry+CoreDataProperties.swift
//
//
//  Created by Claude Code (guided by Peter van den Hamer) on 31/10/2026.
//
//  Written by hand in the form Xcode generates. Codegen is Manual/None, so this file is maintained by hand (see README).
//

public import Foundation
public import CoreData

public typealias LogEntryCoreDataPropertiesSet = NSSet

extension LogEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LogEntry> {
        return NSFetchRequest<LogEntry>(entityName: "LogEntry")
    }

    @NSManaged nonisolated public var author_: String?
    @NSManaged nonisolated public var date_: Date?
    @NSManaged nonisolated public var isFormerOrganization_: NSNumber?
    @NSManaged nonisolated public var originalDataSourceLevel: Int16
    @NSManaged nonisolated public var position: Int16
    @NSManaged nonisolated public var text_: String?
    @NSManaged nonisolated public var organization_: Organization?

}

extension LogEntry : Identifiable {

}
