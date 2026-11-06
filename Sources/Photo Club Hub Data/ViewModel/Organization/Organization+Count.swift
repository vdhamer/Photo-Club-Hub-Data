//
//  Organization+Count.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 28/11/2025.
//

import CoreData

extension Organization {

    /// Counts only current organizations, leaving out former ones (Data#91), so that the iOS app's README count of
    /// clubs always matches what the Maps and Clubs tabs show (#891).
    public static func count(context: NSManagedObjectContext, organizationTypeE: OrganizationTypeEnum) -> Int {

        let organizationCount: Int = context.performAndWait {

            let organizationType: OrganizationType =
                OrganizationType.findCreateUpdate(context: context,
                                                  orgTypeName: organizationTypeE.unlocalizedSingular)
            let fetchRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
            let predicateFormat: String = "organizationType_ = %@" // avoid localization
            let typePredicate = NSPredicate(format: predicateFormat, argumentArray: [organizationType])
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [typePredicate,
                                                                                         Organization.currentPredicate])

            do {
                return try context.fetch(fetchRequest).count
            } catch {
                ifDebugFatalError(
                    "Failed to fetch Organizations of type \(organizationType.organizationTypeName): \(error)",
                    file: #fileID, line: #line)
                return 0
            }
        }

        return organizationCount
    }
}
