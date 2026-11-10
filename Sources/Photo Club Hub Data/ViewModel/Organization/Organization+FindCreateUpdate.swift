//
//  Organization+FindCreateUpdate.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 28/11/2025.
//

import CoreData // for Core Data access
import CoreLocation // for CLLocationCoordinate2D

extension Organization {

    @available(*, unavailable)
    convenience init() {
        fatalError("init() is not available. Use .findCreateUpdate instead.")
    }

    // MARK: - findCreateUpdate() and private update()

    // Find existing organization or create a new one
    // Update new or existing organization's attributes
    // Thin wrapper that hops onto the context's own queue, so this is safe to call from any thread.
    public static func findCreateUpdate(context: NSManagedObjectContext, // can be foreground or background context
                                        organizationTypeEnum: OrganizationTypeEnum,
                                        idPlus: OrganizationIdPlus,
                                        coordinates: CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0),
                                        obsolete: Bool = false, // can remove records for removed org's
                                        optionalFields: OrganizationOptionalFields = OrganizationOptionalFields(),
                                        pinned: Bool = false) -> Organization {
        // Safe: performAndWait runs synchronously on the context's queue; nothing actually escapes.
        // performAndWait is synchronous and reentrant on this context's queue,
        // so findCreateUpdate_() is never called concurrently or after return.
        nonisolated(unsafe) let optionalFields = optionalFields
        return context.performAndWait {
            findCreateUpdate_(context: context,
                              organizationTypeEnum: organizationTypeEnum,
                              idPlus: idPlus,
                              coordinates: coordinates,
                              obsolete: obsolete,
                              optionalFields: optionalFields,
                              pinned: pinned)
        }
    }

    private static func findCreateUpdate_(context: NSManagedObjectContext, // can be foreground or background context
                                          organizationTypeEnum: OrganizationTypeEnum,
                                          idPlus: OrganizationIdPlus,
                                          coordinates: CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0),
                                          obsolete: Bool = false, // can remove records for removed org's
                                          optionalFields: OrganizationOptionalFields = OrganizationOptionalFields(),
                                          pinned: Bool = false) -> Organization {

        let predicateFormat: String = "fullName_ = %@ AND town_ = %@" // avoid localization
        // Note that organizationType is not an identifying attribute.
        // This implies that you cannot have 2 organizations with the same Name and Town, but of a different type.
        let predicate = NSPredicate(format: predicateFormat,
                                    argumentArray: [idPlus.fullName,
                                                    idPlus.town] )
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        let organizations: [Organization] = (try? context.fetch(fetchRequest)) ?? []

        if organizations.count > 1 { // organization exists, but there shouldn't be multiple that satify the predicate
            ifDebugFatalError("Query returned \(organizations.count) organizations named " +
                              "\(idPlus.fullName) in \(idPlus.town)",
                              file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
            // in release mode, log that there are multiple clubs, but continue using the first one.
        }

        if let organization = organizations.first { // already exists, so make sure non-ID attributes are up to date
            print("\(organization.fullNameTown): Will try to update info for organization \(organization.fullName)")
            if organization.update(bgContext: context,
                                   organizationTypeEnum: organizationTypeEnum,
                                   nickName: idPlus.nickname,
                                   coordinates: coordinates,
                                   obsolete: obsolete,
                                   optionalFields: optionalFields,
                                   pinned: pinned) {
                print("""
                  \(organization.fullNameTown): Successfully updated existing organization \(organization.fullName)
                  """)
            }
            return organization
        } else { // Have to create Organization object because it doesn't exist yet
            // Cannot use Organization() initializer because we must use bgContext.
            // Resolve the type BEFORE inserting the organization: on its create path.
            // OrganizationType.findCreateUpdate() saves the context, and any organization already
            // inserted here would be committed - and published to the live viewContext - while its
            // organizationType_ was still nil, which the (non-optional) getter treats as fatal.
            // Some fancy footwork because organization type info originated from other context
            let organizationType = OrganizationType.findCreateUpdate(context: context,
                                                                     orgTypeName: organizationTypeEnum.rawValue)
            let entity = NSEntityDescription.entity(forEntityName: "Organization", in: context)!
            let organization = Organization(entity: entity, insertInto: context) // create new Club or Museum
            organization.fullName = idPlus.fullName // first part of ID
            organization.town = idPlus.town // second part of ID
            organization.organizationType = organizationType
            print("\(organization.fullNameTown): Will try to fill fields for this new organization")
            _ = organization.update(bgContext: context,
                                    organizationTypeEnum: organizationTypeEnum,
                                    nickName: idPlus.nickname,
                                    coordinates: coordinates,
                                    obsolete: obsolete,
                                    optionalFields: optionalFields,
                                    pinned: pinned)
            print("\(organization.fullNameTown): Successfully created new \(organizationTypeEnum.rawValue)")
            return organization
        }
    }

    // Update non-identifying attributes/properties within existing instance of class Organization
    // swiftlint:disable:next function_parameter_count cyclomatic_complexity function_body_length
    private func update(bgContext: NSManagedObjectContext,
                        organizationTypeEnum: OrganizationTypeEnum,
                        nickName: String,
                        coordinates: CLLocationCoordinate2D,
                        obsolete: Bool, // used to remove records for org's that disappeared
                        optionalFields: OrganizationOptionalFields,
                        pinned: Bool) -> Bool {

        var modified: Bool = false

        // A missing JSON nickName arrives as "" (SwiftyJSON's .stringValue), and must not clear a stored one.
        if !nickName.isEmpty, self.nickName_ != nickName {
            self.nickName_ = nickName
            modified = true }

        // (0,0) is the "no data" sentinel (Null Island); skip it to avoid clobbering real coordinates.
        let coordinatesProvided = abs(coordinates.latitude)  > 0.000001 ||
                                  abs(coordinates.longitude) > 0.000001
        // allow small rounding differences in double (instead of using != for Doubles)
        let deltaCoordinates = abs(self.latitude_  - coordinates.latitude) +
                               abs(self.longitude_ - coordinates.longitude)
        if coordinatesProvided, deltaCoordinates > 0.000001 {
            self.longitude_ = coordinates.longitude
            self.latitude_  = coordinates.latitude
            modified = true }

        if self.obsolete != obsolete {
            self.obsolete = obsolete
            modified = true }

        if let logEntries = optionalFields.logEntries,
                            updateStoredLogEntries(fileRows: logEntries, level: .level1, bgContext: bgContext) {
            modified = true }

        if let isFormer = optionalFields.isFormerOrganization, self.isFormerOrganization != isFormer {
            self.isFormerOrganization = isFormer
            modified = true }

        // Before the website, which depends on the bad websites being up to date.
        if let badWebsites = optionalFields.badWebsites {
            let newBadWebsites: String? = badWebsites.isEmpty ? nil : badWebsites.joined(separator: "\n")
            if self.badWebsites_ != newBadWebsites {
                self.badWebsites_ = newBadWebsites
                modified = true }
        }

        // This check runs for every caller, because a Level 2 file can supply a website that Level 1 lists as bad.
        if let website = optionalFields.organizationWebsite,
                         self.organizationWebsite != website, !isBadListed(website) {
            self.organizationWebsite = website
            modified = true }

        if let storedWebsite = self.organizationWebsite, isBadListed(storedWebsite) {
            self.organizationWebsite = nil
            modified = true }

        if let level2URL = optionalFields.level2URL, self.level2URL_ != level2URL {
            self.level2URL_ = level2URL
            modified = true }

        if let wikiURL = optionalFields.wikipedia, self.wikipedia != wikiURL {
            self.wikipedia = wikiURL
            modified = true }

        if let maintainerEmail = optionalFields.maintainerEmail, self.maintainerEmail != maintainerEmail {
            self.maintainerEmail = maintainerEmail
            modified = true }

        if let fotobondClubNumber = optionalFields.fotobondClubNumber, self.fotobondClubNumber != fotobondClubNumber {
            self.fotobondClubNumber = fotobondClubNumber
            modified = true }

        if self.pinned != pinned {
            self.pinned = pinned
            modified = true }

        for localizedRemark in optionalFields.localizedRemarks { // load JSON localizedRemarks for provided languages
            let isoCode: String? = localizedRemark["language"].stringValue.lowercased() // e.g. "nl", "de" or "pdc"
            let localizedRemarkNewValue: String? = localizedRemark["value"].stringValue

            if isoCode != nil && localizedRemarkNewValue != nil { // nil could occur if JSON file isn't schema compliant
                let language = Language.findCreate(context: bgContext,
                                                   isoCode: isoCode!) // find or construct the remark's Language
                // language updates doesn't set modified flag

                let remarkNeedsPersisting: Bool = LocalizedRemark.findCreateUpdate(
                    bgContext: bgContext, // create object
                    organization: self,
                    language: language,
                    localizedString: localizedRemarkNewValue!
                )
                if remarkNeedsPersisting { modified = true }
            }
        } // end of loop over remark in all provided languages

        if bgContext.hasChanges {
            do {
                try bgContext.save() // persist modifications in PhotoClub record
            } catch {
                print("Error: \(error)")
                ifDebugFatalError("Update failed for organization \"\(fullName)\"",
                                  file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
                // in release mode, if .save() fails, just continue
                return false
            }
        }
        return modified
    }

    // MARK: - LogEntry functionality

    // Makes the stored rows match the array in the file:
    // An existing row is updated in place, because the entry at a given position is the same entry
    // unless someone edited it by hand.
    // Rows past the end of the array are deleted.
    // Each value is compared first, to avoid dirtying the context on every load.
    private func updateStoredLogEntries(fileRows: [LogEntryFields],
                                        level: DataSourceLevel, // the level of the file that fileRows came from
                                        bgContext: NSManagedObjectContext) -> Bool {
        var modified: Bool = false // value that is returned: did this change anything in the CoreData store

        // what's originally in the CoreData store; that may change. Only rows of this level: each level has its own
        // positions, so rows of different levels must never be matched, updated or deleted here.
        let storedRows: [LogEntry] = self.logEntries.filter { $0.dataSourceLevel == level }

        // Only called if there is no stored row at this position yet (new entry, or the file got longer)
        func createRow(at position: Int16) -> LogEntry {
            let entity = NSEntityDescription.entity(forEntityName: "LogEntry", in: bgContext)!
            let newRow = LogEntry(entity: entity, insertInto: bgContext)
            newRow.position = position
            newRow.originalDataSourceLevel = level.rawValue // set explicitly rather than rely on the model's default
            newRow.organization_ = self // link the new row to this organization
            modified = true
            return newRow
        }

        for (index, fileRow) in fileRows.enumerated() { // starting at logEntries[0], etc.; keeps the file's order
            // The array index is the row's identity: the entry at index n in the file maps to the row at position n
            let fileRowPosition = Int16(index) // index into fileRows array. The array order fully determines this.
            // Reuse the existing stored row if there is one, so its values are compared and updated below.
            // Note: fileRows (JSON) have an order and the position is determined by counting them ("index")
            //       storedRows (database) are a set, so an extra position Int16 is added to sort them in order
            let storedRow: LogEntry = storedRows.first(where: { $0.position == fileRowPosition }) // already exists
                                      ?? createRow(at: fileRowPosition) // new row for that index value

            // Copy each field only if it differs, so an unchanged file leaves the context clean
            if storedRow.date_ != fileRow.date {
                storedRow.date_ = fileRow.date
                modified = true }
            if storedRow.author_ != fileRow.author {
                storedRow.author_ = fileRow.author
                modified = true }
            if storedRow.text_ != fileRow.text {
                storedRow.text_ = fileRow.text
                modified = true }
            if storedRow.isFormerOrganization != fileRow.isFormerOrganization {
                if let isFormer = fileRow.isFormerOrganization { // CoreData stores an optional Bool as NSNumber?
                    storedRow.isFormerOrganization_ = NSNumber(value: isFormer)
                } else {
                    storedRow.isFormerOrganization_ = nil
                }
                modified = true
            }
        }

        // The file got shorter: rows at positions beyond the last entry no longer exist in the file
        for storedRow in storedRows where storedRow.position >= fileRows.count {
            bgContext.delete(storedRow)
            modified = true
        }

        return modified
    }

    // Is this website on the organization's list of bad websites (`badWebsites`, set by a Level 1 file)?
    // Used in two directions: to refuse a new website that is listed as bad, and to clear a stored website
    // that has since been listed as bad.
    private func isBadListed(_ website: URL) -> Bool {
        let websiteToCheck: String = website.canonicalString // computed once, outside the loop below
        return badWebsites.contains { $0.canonicalString == websiteToCheck }
    }

    // MARK: - find variants

    // Thin wrapper that hops onto the context's own queue, so this is safe to call from any thread.
    public static func find(context: NSManagedObjectContext, // can be foreground or background context
                            organizationID: OrganizationID) throws -> Organization {
        try context.performAndWait {
            try find_(context: context, organizationID: organizationID)
        }
    }

    private static func find_(context: NSManagedObjectContext, // can be foreground or background context
                              organizationID: OrganizationID) throws -> Organization {

        let predicateFormat: String = "fullName_ = %@ AND town_ = %@" // avoid localization
        // Note that organizationType is not an identifying attribute.
        // This implies that you cannot have 2 organizations with the same Name and Town, but of a different type.
        let predicate = NSPredicate(format: predicateFormat,
                                    argumentArray: [organizationID.fullName, organizationID.town] )
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        let organizations: [Organization] = (try? context.fetch(fetchRequest)) ?? []

        if organizations.count > 1 { // organization exists, but there shouldn't be multiple that satify the predicate
            ifDebugFatalError("Query returned \(organizations.count) organizations named " +
                              "\(organizationID.fullName) in \(organizationID.town)",
                              file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
            // in release mode, log that there are multiple clubs, but continue using the first one.
        }

        if let org = organizations.first {
            return org
        } else {
            throw CoreDataError.cantFindOrg(
                "No organization found matching \(organizationID.fullName) in \(organizationID.town)")
        }
    }

    // Thin wrapper that hops onto the context's own queue, so this is safe to call from any thread.
    public static func find(context: NSManagedObjectContext, // can be foreground or background context
                            nickname: String) throws -> Organization {
        try context.performAndWait {
            try find_(context: context, nickname: nickname)
        }
    }

    private static func find_(context: NSManagedObjectContext, // can be foreground or background context
                              nickname: String) throws -> Organization {

        let predicateFormat: String = "nickName_ = %@" // avoid localization
        // stored nicknames use plain typography, so "Witte’s Museum" also finds "Witte's Museum" (Data#100)
        let predicate = NSPredicate(format: predicateFormat, argumentArray: [nickname.normalizedTypography] )
        let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
        fetchRequest.predicate = predicate
        let organizations: [Organization] = (try? context.fetch(fetchRequest)) ?? []

        if organizations.count > 1 { // organization exists, but there shouldn't be multiple that satify the predicate
            ifDebugFatalError("Query returned \(organizations.count) organizations nicknamed \(nickname)",
                              file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
            // in release mode, log that there are multiple clubs, but continue using the first one.
        }

        if let org = organizations.first {
            return org
        } else {
            throw CoreDataError.cantFindOrg(
                "No organization found matching nickname \(nickname)")
        }
    }

    fileprivate enum CoreDataError: Error {
        case cantFindOrg(_ message: String)
    }

}
