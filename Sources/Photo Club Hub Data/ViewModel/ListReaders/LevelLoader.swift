//
//  LevelLoader.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 06/08/2026.
//

import CoreData // for NSManagedObjectContext, NSPersistentContainer, NSMergePolicy

/// Coordinates the order in which the levels are loaded, and owns the Core Data settings that order depends on.
///
/// This functionality used to reside  in each consuming app, which meant the rule below was implemented twice,
/// with two different concurrency models (Data#12).
/// But the invariant belongs to the Data package because it owns the loading of the various Levels.
public enum LevelLoader {

    /// The built-in Level 1 root: the entry point of this project's own Include tree.
    ///
    /// The underscore matters. `root.level1.json` is the pre-Include flat file that app versions before
    /// 2.9.0 still fetch, so the two names select different content for different audiences. Retiring
    /// that split — which turns this constant back into `"root"` — is Data#45.
    static let builtInLevel1RootName = "root_"

    /// Runs one complete load pass:
    /// - Level 0 (awaited to completion), then
    /// - Level 1, then
    /// - every Level 2 club loader concurrently; returning only once every loader has finished.
    /// In this manner a caller can get a guarantee that a load pass has been fully executed.
    ///
    /// **Why Level 0 is awaited first.** `Expertise.update()` promotes `isSupported` from false to true and never
    /// demotes, and `LoadOrderIndependenceTest` checks that a Level-2-then-Level-0 sequence reaches the same state as
    /// the reverse. The `await` is about contention. `Expertise` has a uniqueness constraint on `id_`, and two contexts
    /// that cannot see each other's uncommitted insert both create a row; the store then settles that collision
    /// property by property, below the latch, so a promotion can be dropped (`MergePolicyTest`).
    ///
    /// Awaiting Level 0 commits every expertise on its list (with `isSupported == true`) before the Level 2 runs, so
    /// those loaders find those rows rather than insert them. What is left to insert are ad-hoc expertises that are not
    /// on the Level 0 list, where colliding clubs write the same value and the constraint deduplicates harmlessly. Same
    /// move as `initConstants()` pre-creating the contended Language and OrganizationType rows; the merge policy only
    /// decides how an *unsequenced* load fails.
    ///
    /// Level 1 is awaited too, but only for simplicity: Level 1 and Level 2 may overlap.
    ///
    /// - Parameter usedContainer: the container whose background contexts every level loads into. Defaults
    ///   to the app's shared store; tests inject a private in-memory store for isolation. It is the only
    ///   Core Data decision a consumer makes — the merge policy is deliberately not a parameter, because
    ///   the apps used to disagree about it and the invariant above is the package's to protect.
    public static func loadAllLevels(usedContainer: NSPersistentContainer = PersistenceController.shared.container,
                                     isBeingTested: Bool = false,
                                     useOnlyInBundleFile: Bool = false, // can skip loading current version from GitHub
                                     level1RootURL: URL? = nil
                                     // ^ a Level 1 root named by the user instead of the built-in default one
                                     //   (Photo-Club-Hub#829). nil leaves every behavior below unchanged.
                                     //   non-nil expected to be used in specialized use-cases (e.g. stress testing)
                                    ) async {

        // The hardcoded Level 2 clubs are skipped for any custom root, since those 15 clubs are the
        // production tree's own content: loading them over another tree would inject organizations it
        // never listed. Level 0 is deliberately not conditional. Its expertises and languages come from
        // this project's own file, cost nothing when an external tree never references them, and the
        // languages are needed either way. A tree wanting its own vocabulary is better served by a
        // Level 0 override, once there is a use case, than by this package guessing whose data a URL holds.
        let usesCustomRoot: Bool = level1RootURL != nil

        // MARK: - Level 0

        // load list of Expertises and Languages from root.level0.json file
        await Level0JsonReader.load(
            bgContext: makeBgContext(ctxName: "Level 0 loader", usedContainer: usedContainer),
            isBeingTested: isBeingTested,
            useOnlyInBundleFile: useOnlyInBundleFile)

        // MARK: - Level 1

        // Load list of organizations from root_.level1.json file - which can pull in additional Level 1 "include" files
        let fileName: String
        if let level1RootURL {
            fileName = Level1Source.fileName(of: level1RootURL)
        } else {
            fileName = Self.builtInLevel1RootName
        }

        await Level1JsonReader.load(
            bgContext: makeBgContext(ctxName: "Level 1 loader for \(fileName)", usedContainer: usedContainer),
            fileName: fileName,
            isBeingTested: isBeingTested,
            useOnlyInBundleFile: useOnlyInBundleFile,
            usedContainer: usedContainer, // propagate so the whole Include tree shares one storage container
            explicitRemoteURL: level1RootURL,
            // A custom root has no embedded copy of its custom data, so there is nothing to fall
            // back to. Saying so explicitly also stops a file from outside this project, from sharing a name
            // with a bundled one, from quietly serving this project's clubs instead.
            allowBundleFallback: !usesCustomRoot)

        // MARK: - Level 2

        guard !usesCustomRoot else { return } // see the note above on why these clubs are production-only

        await loadAllLevel2Clubs(usedContainer: usedContainer,
                                 isBeingTested: isBeingTested,
                                 useOnlyInBundleFile: useOnlyInBundleFile)
    }

    // Loads every club that has a Level 2 file, concurrently, and returns when the last one has finished.
    //
    // This list is scaffolding with a known end date: Data#8 replaces it with Level 2 driven from Level 1
    // data, which deletes this function whole. So it is deliberately a flat list of calls rather than a
    // registry, a config type or per-club options — all of which would be deleted again.
    // swiftlint:disable:next function_body_length
    private static func loadAllLevel2Clubs(usedContainer: NSPersistentContainer,
                                           isBeingTested: Bool,
                                           useOnlyInBundleFile: Bool) async {

        await withDiscardingTaskGroup { group in // discarding: child tasks return no results
            group.addTask {
                await FotogroepDeGenderMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fgDeGender", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotogroepWaalreMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fgWaalre", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotoclubBellusImagoMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fcBellusImago", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotogroepOirschotMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fgOirschot", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await TemplateMinMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader TemplateMin", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await TemplateMaxMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader TemplateMax", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await Persoonlijk16MembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader Persoonlijk16", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotoclubEricameraMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fcEricamera", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotoclubDenDungenMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fcDenDungen", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotokringStMichielsgestelMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fkGestel", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await Persoonlijk03MembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader Persoonlijk03", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FotoclubVeghelMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fcVeghel", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FFCShot71MembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader ffcShot71", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
            group.addTask {
                await FEGGemertMembersProvider.load(
                    bgContext: makeBgContext(ctxName: "Level 2 loader fegGemert", usedContainer: usedContainer),
                    isBeingTested: isBeingTested,
                    useOnlyInBundleFile: useOnlyInBundleFile)
            }
        }
    }

    /// The place where all background contexts for loading are configured.
    ///
    /// `mergeByPropertyStoreTrump` rather than `ObjectTrump`: with the sequencing above in place the policy
    /// does not affect `Expertise.isSupported` either way - but if the sequencing ever breaks - StoreTrump is
    /// the configuration that fails safely.
    /// Package consumers cannot override it — the two apps originally used different settings (for vague reasons).
    static func makeBgContext(ctxName: String, usedContainer: NSPersistentContainer) -> NSManagedObjectContext {

        let bgContext = usedContainer.newBackgroundContext()
        bgContext.name = ctxName
        if inDebugMode && Settings.errorOnCoreDataMerge {
            bgContext.mergePolicy = NSMergePolicy.error // to force detection of Core Data merge issues
        } else {
            bgContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        }
        bgContext.automaticallyMergesChangesFromParent = true // to push ObjectTypes to bgContext?
        bgContext.undoManager = nil // no undo manager (for speed)
        return bgContext

    }
}
