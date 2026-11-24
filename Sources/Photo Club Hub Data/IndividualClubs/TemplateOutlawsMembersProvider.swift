//
//  TemplateOutlawsMembersProvider.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 24/11/2026.
//

import CoreData // for NSManagedObjectContext

/// Loads the members of the template organization that was rejected (vdhamer/Photo-Club-Hub#690), so that the
/// Clubs and People tabs can be checked to hide them, as the Maps tab hides the organization itself.
///
/// Internal, unlike the other providers, so that adding it adds no public API. It has only the awaitable `load`,
/// because `LevelLoader.loadAllLevel2Clubs` is its only caller. Data#8 deletes it together with the other providers.
enum TemplateOutlawsMembersProvider {

    static func load(bgContext: NSManagedObjectContext,
                     isBeingTested: Bool,
                     useOnlyInBundleFile: Bool) async {
        let idPlus = OrganizationIdPlus(fullName: "Template Gang of Outlaws",
                                        town: "Gibsland",
                                        nickname: "TemplateOutlaws")
        await Level2JsonReader.load(bgContext: bgContext, organizationIdPlus: idPlus,
                                    isBeingTested: isBeingTested, useOnlyInBundleFile: useOnlyInBundleFile)
    }

}
