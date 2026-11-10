//
//  LevelLoaderTest.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 06/08/2026.
//

import Testing
@testable import Photo_Club_Hub_Data
import CoreData // for NSManagedObjectContext, NSPersistentContainer
import Foundation // for NSLock, NotificationCenter

// Data#12: "Level 0 must complete and save before Level 2 starts" was formerly implemented in the
// consuming apps and tested by neither. Now that LevelLoader owns the sequencing, this asserts it.
//
// The assertion is on *save order*, not on start order, because saving is what the invariant is about:
// the Expertise uniqueness constraint on id_ only resolves a collision when two contexts both `save()`.
// Observing NSManagedObjectContextDidSave gives that directly, without resorting to sleeps or polling.
//
// `.serialized` is load-bearing, not tidiness: the first test observes NSManagedObjectContextDidSave,
// which is a process-global notification stream. It filters on its own store's coordinator, so a
// concurrent pass cannot corrupt what it records — but serializing keeps the recorded order easy to
// reason about when a failure has to be diagnosed from the message alone.
// The visited-file guard needs no such care any more: each pass owns its own Level1History.
@MainActor
@Suite("LevelLoader sequences the levels", .serialized)
struct LevelLoaderTests {

    /// Records the names of contexts that saved, in the order the saves committed.
    ///
    /// Saves commit on the background contexts' own queues, so recording needs a lock.
    /// NSLock rather than Mutex to match the rest of the package, which still supports iOS 17.
    private final class SaveOrderRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var names: [String] = []

        func record(_ name: String) {
            lock.lock()
            defer { lock.unlock() }
            names.append(name)
        }

        var recorded: [String] {
            lock.lock()
            defer { lock.unlock() }
            return names
        }
    }

    @Test("Level 0 saves before any Level 2 loader saves")
    func level0SavesBeforeLevel2() async {
        // A private in-memory store, so this suite neither sees nor disturbs the app's store or other tests.
        let persistenceController = PersistenceController(inMemory: true)
        let coordinator = persistenceController.container.persistentStoreCoordinator

        let recorder = SaveOrderRecorder()
        // Filtering on the coordinator matters: NSManagedObjectContextDidSave is process-global, and
        // Swift Testing runs suites in parallel, so an unfiltered observer would also record saves made
        // by unrelated tests (the flakiness described in Data#1).
        let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave,
                                                             object: nil,
                                                             queue: nil) { notification in
            guard let context = notification.object as? NSManagedObjectContext,
                  context.persistentStoreCoordinator === coordinator,
                  let name = context.name else { return }
            recorder.record(name)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await LevelLoader.loadAllLevels(usedContainer: persistenceController.container,
                                        isBeingTested: true,
                                        useOnlyInBundleFile: true) // no network: use the bundled JSON files

        let saveOrder = recorder.recorded
        let level0Index = saveOrder.firstIndex(of: "Level 0 loader")
        let firstLevel2Index = saveOrder.firstIndex { $0.hasPrefix("Level 2 loader") }

        #expect(level0Index != nil, "Level 0 never saved; save order was \(saveOrder)")
        #expect(firstLevel2Index != nil, "No Level 2 loader saved; save order was \(saveOrder)")

        if let level0Index, let firstLevel2Index {
            #expect(level0Index < firstLevel2Index,
                    "Level 0 must save before any Level 2 loader; save order was \(saveOrder)")
        }
    }

    @Test("Every expertise Level 0 declares is still supported after a full load pass")
    func level0ExpertisesStaySupported() async {
        // The consequence of the ordering, checked on the data rather than on the schedule.
        // The baseline is derived from a Level-0-only load rather than hard-coded, so the assertion keeps
        // its meaning when root.level0.json gains or loses an expertise.
        let baselineController = PersistenceController(inMemory: true)
        await Level0JsonReader.load(
            bgContext: LevelLoader.makeBgContext(ctxName: "Level 0 loader",
                                                 usedContainer: baselineController.container),
            isBeingTested: true,
            useOnlyInBundleFile: true)
        let declaredIDs = supportedExpertiseIDs(in: baselineController)
        #expect(declaredIDs.isEmpty == false, "Level 0 declared no supported expertises at all")

        let fullPassController = PersistenceController(inMemory: true)
        await LevelLoader.loadAllLevels(usedContainer: fullPassController.container,
                                        isBeingTested: true,
                                        useOnlyInBundleFile: true)
        let survivingIDs = supportedExpertiseIDs(in: fullPassController)

        // Expertises that only Level 2 references are legitimately unsupported ("temporary"), so the
        // assertion is one-directional: nothing Level 0 declared may have been downgraded.
        let downgraded = declaredIDs.subtracting(survivingIDs)
        #expect(downgraded.isEmpty,
                "Level 2 downgraded these Level 0 expertises to temporary: \(downgraded.sorted())")
    }

    @Test("Two load passes in one process do not trip the visited-file guard",
          .usesIfDebugFatalErrorSpy)
    func secondPassIsNotADuplicate() async {
        // The visited-file guard used to be a process-global singleton, so a second pass without an
        // intervening Model.deleteCoreDataObjects reported every Level 1 file as an infinite loop or
        // duplicate. Each pass now owns its Level1History, which is what this pins down.
        //
        // The spy is what makes the assertion possible at all: without it the guard's ifDebugFatalError
        // would abort the whole test run in a DEBUG build rather than fail this one test.
        let spy = makeIfDebugFatalErrorSpy()
        installIfDebugFatalErrorSpy(spy)
        defer { removeIfDebugFatalErrorSpy() } // spy is process-global, so remove it promptly

        let persistenceController = PersistenceController(inMemory: true)
        for pass in 1...2 {
            await LevelLoader.loadAllLevels(usedContainer: persistenceController.container,
                                            isBeingTested: true,
                                            useOnlyInBundleFile: true)
            #expect(spy.messages.isEmpty, "Pass \(pass) reported: \(spy.messages)")
        }
    }

    @Test("Every organization name, town, nickname and remark, and every photographer name, uses plain typography")
    func namesStoredWithPlainTypography() async {
        // Data#100: the Level 1 files may write "’s-Gravenzande" or "MOMus–Thessaloniki", but the store holds the
        // plain form. This checks every production file on every run, so a new path that writes a name, town or
        // nickname without going through OrganizationID(Plus) or the Organization setters, a remark without going
        // through LocalizedRemark.findCreateUpdate, or a photographer's name without going through PersonName,
        // shows up here.
        // Apple's towns and countries aren't covered: this pass makes no network calls, so nothing is geocoded.
        let persistenceController = PersistenceController(inMemory: true)
        await LevelLoader.loadAllLevels(usedContainer: persistenceController.container,
                                        isBeingTested: true,
                                        useOnlyInBundleFile: true)

        let request = NSFetchRequest<Organization>(entityName: "Organization")
        let organizations = (try? persistenceController.container.viewContext.fetch(request)) ?? []
        #expect(organizations.isEmpty == false, "The load pass stored no organizations at all")

        let remarks = organizations.flatMap { organization in
            ((organization.localizedRemarks_ as? Set<LocalizedRemark>) ?? []).map(\.localizedString)
        }
        let typographic = (organizations.flatMap { [$0.fullName_, $0.town_, $0.nickName_] } + remarks)
            .compactMap { $0 }
            .filter { $0 != $0.normalizedTypography }
        #expect(typographic.isEmpty, "Stored with typographic characters: \(typographic.sorted())")

        let photographerRequest = NSFetchRequest<Photographer>(entityName: "Photographer")
        let photographers = (try? persistenceController.container.viewContext.fetch(photographerRequest)) ?? []
        #expect(photographers.isEmpty == false, "The load pass stored no photographers at all")

        let typographicNames = photographers.flatMap { [$0.givenName_, $0.infixName_, $0.familyName_] }
            .compactMap { $0 }
            .filter { $0 != $0.normalizedTypography }
        #expect(typographicNames.isEmpty,
                "Photographer names with typographic characters: \(typographicNames.sorted())")
    }

    @Test("The production JSON files themselves use plain typography")
    func jsonFilesUsePlainTypography() throws {
        // Data#100: the apps normalize when loading, but the review-page scripts in Photo-Club-Hub-Project read these
        // files directly, and website visitors search what those pages show. So the files are kept plain too, and
        // this reads them as files rather than through the store. URLs are percent-encoded, not exempted.
        // Two exceptions. root.level1.json: only app versions before 2.9.0 read it, and Data#45 deletes it.
        // Organization names: iOS 3.0.4 and older would show a straightened name as a duplicate (Data#101 ends this).
        let urls = try #require(Bundle.photoClubHubDataModule.urls(forResourcesWithExtension: "json",
                                                                   subdirectory: nil))
        #expect(urls.count > 40, "Found only \(urls.count) production JSON files")

        var typographic: [String] = []
        for url in urls where url.lastPathComponent != "root.level1.json" {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            for (keyPath, value) in Self.stringValues(in: json, keyPath: "")
            where value != value.normalizedTypography && !keyPath.hasSuffix("idPlus.fullName") {
                typographic.append("\(url.lastPathComponent) \(keyPath): \(value)")
            }
        }
        #expect(typographic.isEmpty, "Typographic characters in production JSON: \(typographic.sorted())")
    }

    @Test("Every nickname in the production JSON uses only ASCII letters, digits and underscore")
    func nicknamesAreIdentifiers() throws {
        // Data#102: a club's nickname is its Level 2 file name, part of its vdhamer.com URL and of the website's
        // members-page path, so a space, slash, "&" or accent there is asking for trouble. Museums follow the same
        // rule, so nothing breaks once code starts building paths from their nicknames too.
        // root.level1.json is skipped: only app versions before 2.9.0 read it, and Data#45 deletes it.
        let urls = try #require(Bundle.photoClubHubDataModule.urls(forResourcesWithExtension: "json",
                                                                   subdirectory: nil))
        let allowed = try Regex("[A-Za-z0-9_]+")

        var nicknames: [String] = []
        var badNicknames: [String] = []
        for url in urls where url.lastPathComponent != "root.level1.json" {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            for (keyPath, value) in Self.stringValues(in: json, keyPath: "")
            where keyPath.hasSuffix("idPlus.nickName") {
                nicknames.append(value)
                if value.wholeMatch(of: allowed) == nil {
                    badNicknames.append("\(url.lastPathComponent) \(keyPath): \(value)")
                }
            }
        }
        #expect(nicknames.count > 100, "Found only \(nicknames.count) nicknames in production JSON")
        #expect(badNicknames.isEmpty, "Nicknames that aren't identifiers: \(badNicknames.sorted())")
    }

    /// Every string value in a parsed JSON tree, with its key path such as "clubs.optional.remark.value".
    private static func stringValues(in node: Any, keyPath: String) -> [(keyPath: String, value: String)] {
        switch node {
        case let dictionary as [String: Any]:
            return dictionary.flatMap { key, value in
                stringValues(in: value, keyPath: keyPath.isEmpty ? key : "\(keyPath).\(key)")
            }
        case let array as [Any]:
            return array.flatMap { stringValues(in: $0, keyPath: keyPath) }
        case let string as String:
            return [(keyPath, string)]
        default:
            return []
        }
    }

    private func supportedExpertiseIDs(in controller: PersistenceController) -> Set<String> {
        let request = NSFetchRequest<Expertise>(entityName: "Expertise")
        let expertises = (try? controller.container.viewContext.fetch(request)) ?? []
        return Set(expertises.filter { $0.isSupported }.map { $0.id })
    }
}
