//
//  FotoclubEricameraMembersProvider.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 29/05/2025.
//

import CoreData // for PersistenceController

final public class FotoclubEricameraMembersProvider: Sendable {

    // Fire-and-forget: this initializer returns immediately and loads the members asynchronously
    // in the background. Use it from the running app, where the UI simply updates once the data
    // arrives and nothing needs to wait for the loading to finish.
    init(bgContext: NSManagedObjectContext,
                isBeingTested: Bool,
                useOnlyInBundleFile: Bool,
                randomTownForTesting: String? = nil) {

        if isBeingTested {
            guard let randomTownForTesting else {
                ifDebugFatalError("Missing randomTownForTesting", file: #file, line: #line)
                return
            }
            bgContext.performAndWait { // execute block synchronously
                insertOnlineMemberData(bgContext: bgContext,
                                       isBeingTested: isBeingTested,
                                       town: randomTownForTesting,
                                       useOnlyInBundleFile: useOnlyInBundleFile)
            }
        } else {
            bgContext.perform { // ... or execute same block asynchronously
                self.insertOnlineMemberData(bgContext: bgContext,
                                            isBeingTested: isBeingTested,
                                            useOnlyInBundleFile: useOnlyInBundleFile)
            }
        }

    }

    // Awaitable: this method suspends until the members have been parsed and saved, then returns.
    // Use it from unit tests (or wherever a completion barrier is needed) so the caller can rely
    // on the data being ready before continuing. The app keeps using `init` (above) instead.
    // Awaiting completion is a join point, not serialization: callers wanting several clubs
    // loaded concurrently fan them out in a `TaskGroup`/`async let` and await the group.
    static func load(bgContext: NSManagedObjectContext,
                            isBeingTested: Bool,
                            useOnlyInBundleFile: Bool) async {
        let idPlus = OrganizationIdPlus(fullName: "Fotoclub Ericamera",
                                        town: "Eindhoven",
                                        nickname: "fcEricamera")
        await Level2JsonReader.load(bgContext: bgContext, organizationIdPlus: idPlus,
                                    isBeingTested: isBeingTested, useOnlyInBundleFile: useOnlyInBundleFile)
    }

    private func insertOnlineMemberData(bgContext: NSManagedObjectContext,
                                        isBeingTested: Bool,
                                        town: String = "Eindhoven",
                                        useOnlyInBundleFile: Bool) {
        let idPlus = OrganizationIdPlus(fullName: "Fotoclub Ericamera",
                                        town: town,
                                        nickname: "fcEricamera")

        let club = Organization.findCreateUpdate(context: bgContext,
                                                 organizationTypeEnum: .club,
                                                 idPlus: idPlus
                                                )
        ifDebugPrint("\(club.fullNameTown): Starting insertOnlineMemberData() in background")

        _ = Level2JsonReader(bgContext: bgContext,
                             organizationIdPlus: idPlus,
                             isBeingTested: isBeingTested,
                             useOnlyInBundleFile: useOnlyInBundleFile)
        do {
            if bgContext.hasChanges {
                try bgContext.save()
            }
        } catch {
            ifDebugFatalError("Failed to save club \(idPlus.nickname)", file: #fileID, line: #line)
        }

    }

}
