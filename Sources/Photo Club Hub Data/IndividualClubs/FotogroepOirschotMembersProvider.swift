//
//  FotogroepOirschotMembersProvider.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 31/05/2025.
//

import CoreData // for PersistenceController

final public class FotogroepOirschotMembersProvider: Sendable {

    public init(bgContext: NSManagedObjectContext,
                isBeingTested: Bool,
                useOnlyInBundleFile: Bool,
                randomTownForTesting: String? = nil) {

        if isBeingTested {
            guard let randomTownForTesting else {
                ifDebugFatalError("Missing randomTownForTesting", file: #file, line: #line)
                return
            }
            bgContext.performAndWait { // ...or execute same block synchronously
                self.insertOnlineMemberData(bgContext: bgContext,
                                            isBeingTested: isBeingTested,
                                            town: randomTownForTesting,
                                            useOnlyInBundleFile: useOnlyInBundleFile)
            }
        } else {
            bgContext.perform { // execute block asynchronously...
                self.insertOnlineMemberData(bgContext: bgContext,
                                            isBeingTested: isBeingTested,
                                            useOnlyInBundleFile: useOnlyInBundleFile)
            }
        }

    }

    private func insertOnlineMemberData(bgContext: NSManagedObjectContext,
                                        isBeingTested: Bool,
                                        town: String = "Oirschot",
                                        useOnlyInBundleFile: Bool) {
        let idPlus = OrganizationIdPlus(fullName: "Fotogroep Oirschot",
                                        town: town,
                                        nickname: "fgOirschot")

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
