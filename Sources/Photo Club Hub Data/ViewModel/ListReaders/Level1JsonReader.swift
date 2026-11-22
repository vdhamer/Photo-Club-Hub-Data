//
//  Level1JsonReader.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 16/12/2023.
//

import CoreData // for NSManagedObjectContext
import CoreLocation // for CLLocationCoordinate2D
import SwiftyJSON // for JSON struct

private let organizationTypesToLoad: [OrganizationTypeEnum] = [.club, .museum] // types are loaded one-by-one

class Level1JsonReader {

    /// Fire-and-forget entry point for callers that don't need to know when loading completes
    /// (the sync Level 1 tests and the MapView preview). The app and the "Include" hierarchy
    /// recursion use the awaitable `load(...)` instead (issue #760).
    ///
    /// Deliberately enqueues on `bgContext` directly (rather than `Task { await load(...) }`):
    /// for a file WITHOUT `Includes` all work then runs in one block on the context's serial queue,
    /// so a caller-issued `bgContext.performAndWait { }` still acts as a completion barrier —
    /// the synchronous Level 1 reader tests rely on exactly that.
    init(bgContext: NSManagedObjectContext,
         fileName: String, // no default: "root" names the legacy flat file (Data#45)
         isBeingTested: Bool,
         useOnlyInBundleFile: Bool, // true can be used to avoid publishing a test file to GitHub
         includeFilePath: [String] = [], // captures recursion path like ["root","museums","museumsNL"]
         usedContainer: NSPersistentContainer = PersistenceController.shared.container,
         // ^ container whose background contexts `Included` files load into; defaults to the app's
         //   shared store, but tests can inject a private in-memory store for isolation.
         history: Level1History = Level1History()
         // ^ visited-file guard for THIS pass; the default gives each top-level call its own,
         //   and the Include recursion propagates it so one tree shares one guard.
        ) {
        var extendedIncludeFilePath: [String] = includeFilePath // copy because parameter itself is `let`
        extendedIncludeFilePath.append(fileName) // extend with extra name

        // The @Sendable processor closure captures `usedContainer` (a Sendable type) so it can
        // forward it down the hierarchy during Include handling.
        _ = FetchAndProcessFile(bgContext: bgContext,
                                fileSelector: FileSelector(fileName: fileName, isBeingTested: isBeingTested),
                                fileFetchOptions: FileFetchOptions(fileType: "json",
                                                                   fileSubType: "level1", // "root.level1.json"
                                                                   useOnlyInBundleFile: useOnlyInBundleFile,
                                                                   isBeingTested: isBeingTested,
                                                                   includeFilePath: extendedIncludeFilePath),
                                fileContentProcessor: {
                                    let useOnlyInBundleFile = $3
                                    let isBeingTested = $4
                                    let includeFilePath = $5
                                    let includes = Level1JsonReader.readRootLevel1Json(
                                        bgContext: $0,
                                        jsonData: $1,
                                        fileSelector: $2,
                                        useOnlyInBundleFile: useOnlyInBundleFile,
                                        isBeingTested: isBeingTested,
                                        includeFilePath: includeFilePath,
                                        history: history)
                                    if includes.isEmpty { return } // no further recursion (important)

                                    Task { // on this fire-and-forget path nobody awaits the includes
                                        await Level1JsonReader.loadIncludes(includes,
                                                           isBeingTested: isBeingTested,
                                                           useOnlyInBundleFile: useOnlyInBundleFile,
                                                           includeFilePath: includeFilePath,
                                                           usedContainer: usedContainer,
                                                           history: history)
                                    }
                                }
        )
    }

    /// Loads `fileName`.level1.json on `bgContext`, suspending until that file AND all files it
    /// (recursively) `Include`s have been processed and saved.
    /// `await`ing this method is the "happens-before" relation the unit tests need;
    /// the app keeps launching it from a `Task {}` so its runtime behavior stays fire-and-forget (issue #760).
    static func load(bgContext: NSManagedObjectContext,
                     fileName: String, // no default: "root" names the legacy flat file (Data#45)
                     isBeingTested: Bool,
                     useOnlyInBundleFile: Bool, // true can be used to avoid publishing a test file to GitHub
                     includeFilePath: [String] = [], // recursion path like ["root","museums","museumsNL"]
                     usedContainer: NSPersistentContainer = PersistenceController.shared.container,
                     // ^ container whose background contexts `Included` files load into; defaults to the app's
                     //   shared store, but tests can inject a private in-memory store for isolation.
                     history: Level1History = Level1History(),
                     // ^ visited-file guard for THIS pass; the default gives each top-level call its own
                     //   Level1History, and the Include recursion propagates it so one tree shares one guard.
                     explicitRemoteURL: URL? = nil,
                     // ^ where to fetch this file, instead of composing a URL from `fileName` (#829).
                     //   Set for a user-supplied root and for every Include reached from one.
                     allowBundleFallback: Bool = true
                     // ^ false for data outside this project, which has no embedded copy to stand in.
                     //   Propagated down the Include tree, since the Includes of an external root are external too.
                    ) async {
        var extendedIncludeFilePath: [String] = includeFilePath // copy because parameter itself is `let`
        extendedIncludeFilePath.append(fileName)

        // Parse-and-save runs inside the context's synchronous `perform` block, where a task group
        // cannot be awaited. So the block only *returns* the names of the `Include`d files, and the
        // concurrent include fan-out is hoisted out here (issue #760, "Restructuring note").
        let includes: [Level1Source] = await FetchAndProcessFile.fetchAndProcess(
            bgContext: bgContext,
            fileSelector: FileSelector(fileName: fileName, isBeingTested: isBeingTested),
            fileFetchOptions: FileFetchOptions(fileType: "json",
                                               fileSubType: "level1", // "root.level1.json"
                                               useOnlyInBundleFile: useOnlyInBundleFile,
                                               isBeingTested: isBeingTested,
                                               includeFilePath: extendedIncludeFilePath,
                                               explicitRemoteURL: explicitRemoteURL,
                                               allowBundleFallback: allowBundleFallback),
            fileContentProcessor: {
                Level1JsonReader.readRootLevel1Json(bgContext: $0,
                                                    jsonData: $1,
                                                    fileSelector: $2,
                                                    useOnlyInBundleFile: $3,
                                                    isBeingTested: $4,
                                                    includeFilePath: $5,
                                                    history: history)
            }
        ) ?? [] // nil (bundle resource not found) means there is nothing to include

        await loadIncludes(includes,
                           isBeingTested: isBeingTested,
                           useOnlyInBundleFile: useOnlyInBundleFile,
                           includeFilePath: extendedIncludeFilePath,
                           usedContainer: usedContainer,
                           history: history,
                           allowBundleFallback: allowBundleFallback)
    }

    // swiftlint:disable function_parameter_count
    /// Parses and stores one level1.json file on the current (background) queue.
    /// Runs inside `bgContext`'s `perform` block, so it cannot await the include fan-out itself;
    /// instead it RETURNS the names of the `Include`d files for `load(...)` to process (issue #760).
    @Sendable static private func readRootLevel1Json(bgContext: NSManagedObjectContext,
                                                     jsonData: String,
                                                     fileSelector: FileSelector,
                                                     useOnlyInBundleFile: Bool,
                                                     isBeingTested: Bool = false,
                                                     includeFilePath: [String],
                                                     history: Level1History) -> [Level1Source] {

        let fileName = fileSelector.fileName
        // If this pass already visited `fileName`, avoid loading it twice.
        // Better performance and prevents infinite loops.
        // `history` is per pass, so a second pass in the same process is not a duplicate.
        if history.isVisitedBefore(fileName: fileName) {
            ifDebugFatalError("Infinite loop or duplicate file in Include tree: \(includeFilePath)")
            return []
        }
        ifDebugPrint("\nWill read \(fileName).level1.json with a list of organizations in the background.")

        // hand the data to SwiftyJSON to parse
        let jsonRoot = JSON(parseJSON: jsonData) // call to SwiftyJSON

        // The file keeps loading either way: stale data beats none (Level1JsonReader+MinimumDataPackageVersion.swift).
        checkMinimumDataPackageVersion(in: jsonRoot, fileName: fileName, history: history)

        let includes: [Level1Source] = extractIncludes(from: jsonRoot)

        // extract the `organizationTypes` in `organizationTypeEnumsToLoad` one-by-one from `jsonRoot`
        for organizationTypeEnum in organizationTypesToLoad {

            let jsonOrganizationsOfOneType: [JSON] = jsonRoot[organizationTypeEnum.unlocalizedPlural].arrayValue
            ifDebugPrint("Found \(jsonOrganizationsOfOneType.count) \(organizationTypeEnum.unlocalizedPlural) " +
                         "in \(fileName).")

            // extract the requested items (clubs, museums) of that organizationType one-by-one from the json file
            for jsonOrganization in jsonOrganizationsOfOneType {
                processOrganization(bgContext: bgContext,
                                         organizationTypeEnum: organizationTypeEnum,
                                         jsonOrganization: jsonOrganization)
            }

        } // end of loop that scans organizationTypeEnumsToLoad

        do { // saving may not be necessary because every organization is saved separately
            if bgContext.hasChanges { // optimization recommended by Apple
                try bgContext.save() // persist contents of entire root.Level1.json file
            }
        } catch {
            ifDebugFatalError("Failed to save changes to Core Data",
                              file: #fileID, line: #line) // likely deprecation of #fileID in Swift 6.0
            // in release mode, the failed database update is only logged. App doesn't stop.
            ifDebugPrint("Failed to save JSON ClubList items in background")
            return includes // a failed save of this file shouldn't block loading the included files
        }

        ifDebugPrint("Completed readRootLevel1Json() in background")
        return includes
    }
    // swiftlint:enable function_parameter_count

    /// Processes a single JSON Organizatio, and creates or updates the corresponding Organization record in Core Data.
    /// - Parameters:
    ///    - bgContext: The managed object context used for Core Data operations.
    ///    - organizationTypeEnum: The type of organization being processed (e.g., Club or Museum).
    ///    - jsonOrganization: The JSON object containing the data for the Organization to process.
    @Sendable static private func processOrganization(bgContext: NSManagedObjectContext,
                                                      organizationTypeEnum: OrganizationTypeEnum,
                                                      jsonOrganization: JSON) {
        let idPlus = OrganizationIdPlus(fullName: jsonOrganization["idPlus"]["fullName"].stringValue,
                                        town: jsonOrganization["idPlus"]["town"].stringValue,
                                        nickname: jsonOrganization["idPlus"]["nickName"].stringValue)
        ifDebugPrint("Adding organization \(idPlus.fullName), \(idPlus.town), aka \(idPlus.nickname).")

        let jsonCoordinates = jsonOrganization["coordinates"]
        let coordinates = CLLocationCoordinate2D(latitude: jsonCoordinates["latitude"].doubleValue,
                                                 longitude: jsonCoordinates["longitude"].doubleValue)

        let jsonOrganizationOptionals = jsonOrganization["optional"] // rest will be empty if not found
        let organizationWebsite = URL(string: jsonOrganizationOptionals["website"].stringValue)
        let level2URL = URL(string: jsonOrganizationOptionals["level2URL"].stringValue)
        let wikipedia = URL(string: jsonOrganizationOptionals["wikipedia"].stringValue)
        let fotobondClubNumberID: Int16? = jsonOrganizationOptionals["nlSpecific"]["fotobondNumber"].exists() ?
            jsonOrganizationOptionals["nlSpecific"]["fotobondNumber"].int16Value : nil
        let maintainerEmail = jsonOrganizationOptionals["maintainerEmail"].stringValue
        let localizedRemarks = jsonOrganizationOptionals["remark"].arrayValue
        var optionalFields = OrganizationOptionalFields(
            organizationWebsite: organizationWebsite,
            level2URL: level2URL,
            wikipedia: wikipedia,
            fotobondClubNumber: FotobondClubNumber(id: fotobondClubNumberID),
            maintainerEmail: maintainerEmail,
            localizedRemarks: localizedRemarks
        )
        // A Level 1 record without these keys has no log or bad websites and is active, so always set them.
        let logEntries: [LogEntryFields] = logEntries(jsonOptionals: jsonOrganizationOptionals,
                                                      fullName: idPlus.fullName)
        optionalFields.logEntries = logEntries
        optionalFields.badWebsites = extractBadWebsites(jsonOptionals: jsonOrganizationOptionals,
                                                        fullName: idPlus.fullName)
        // The last entry with a usable status decides (Data#116). If no entry has one, the organization is active.
        let decidingEntry: LogEntryFields? = logEntries.last { $0.status != nil }
        let statusDefault: OrganizationStatus = .active
        optionalFields.status = decidingEntry?.status ?? statusDefault
        _ = Organization.findCreateUpdate(context: bgContext,
                                          organizationTypeEnum: organizationTypeEnum,
                                          idPlus: idPlus,
                                          coordinates: coordinates,
                                          optionalFields: optionalFields)
    }

    // MARK: - Level 1's LogBook support

    /// Reads the `logbook` array of a Level 1 record (Data#91).
    private static func logEntries(jsonOptionals: JSON,
                                   fullName: String) -> [LogEntryFields] {
        var logEntries: [LogEntryFields] = []
        var precedingDate: Date? // the date of the nearest entry above this one that has a usable date
        let oneDay: TimeInterval = 24 * 60 * 60 // exact, because dates are held as midnight GMT, which has no DST

        for jsonLogEntry in jsonOptionals["logbook"].arrayValue {
            LogEntryFields.checkRequiredKeys(of: jsonLogEntry, fullName: fullName) // can stop a Debug build

            // Stops a Debug build if the date isn't a real calendar day written as YYYY-MM-DD.
            let date: Date? = jsonLogEntry["date"].stringValue.extractDate()

            // Array order is the only order (Data#91), so a date going back suggests an entry added in the wrong
            // place. One day back is allowed, because of time zone differences.
            // Entries without a usable date are skipped, so previousDate may belong to an entry further up.
            if let date, let precedingDate, precedingDate.timeIntervalSince(date) > oneDay {
                let format = Date.ISO8601FormatStyle().year().month().day() // in GMT, like the stored dates
                ifDebugFatalError("Log entry in \(fullName) is dated \(date.formatted(format)), " +
                                  "more than a day before \(precedingDate.formatted(format)) in an entry above it")
            }
            if let date { precedingDate = date }

            let logEntry = LogEntryFields(date: date,
                                          author: jsonLogEntry["author"].string,
                                          text: jsonLogEntry["text"].string,
                                          status: status(of: jsonLogEntry, fullOrgName: fullName))
            logEntries.append(logEntry)
        }

        return logEntries
    }

    /// Reads the `"status"` key of one log entry (Data#116). nil means that the entry doesn't change the status.
    /// A problem that would silently show or hide an organization stops a Debug build. In Release the entry is kept,
    /// with its status ignored.
    private static func status(of jsonLogEntry: JSON, fullOrgName: String) -> OrganizationStatus? {
        // The booleans that `"status"` replaced in Data 3.10.0. No released app read them, so they aren't aliases.
        for key in ["isFormerClub", "isFormerMuseum"] where jsonLogEntry[key].exists() {
            ifDebugFatalError("Log entry in \(fullOrgName) has \(key), which was replaced by \"status\" (Data#116)")
        } // this check can be removed at some point.

        let key = "status"
        guard jsonLogEntry[key].exists() else { return nil }
        // `.string` is nil for anything but a JSON string, such as `true`, so check that separately.
        guard let value: String = jsonLogEntry[key].string else {
            ifDebugFatalError("Log entry in \(fullOrgName) has a \(key) that isn't a string")
            return nil
        }
        guard let status = OrganizationStatus(rawValue: value) else {
            ifDebugFatalError("Log entry in \(fullOrgName) has an unknown \(key) \"\(value)\"")
            return nil
        }
        return status
    }

    /// Reads and returns the `badWebsites` array of a Level 1 record (Data#91), keeping each string as written.
    /// Anything unusable stops a Debug build: an entry that can't be recognized doesn't block its website,
    /// so the apps would still show that website as a clickable link for the club.
    private static func extractBadWebsites(jsonOptionals: JSON, fullName: String) -> [String] {
        let fieldName = "badWebsites"
        guard jsonOptionals[fieldName].exists() else { return [] }

        let jsonBadWebsites: JSON = jsonOptionals[fieldName]
        guard let jsonArray: [JSON] = jsonBadWebsites.array else {
            ifDebugFatalError("\(fieldName) in \(fullName) isn't a valid array, so none of its websites are blocked")
            return []
        }

        var badWebsites: [String] = []
        for jsonBadWebsite in jsonArray {
            guard let badWebsite: String = jsonBadWebsite.string else {
                ifDebugFatalError("\(fieldName) in \(fullName) holds \(jsonBadWebsite), which isn't a string")
                continue // can't be stored as written
            }
            badWebsites.append(badWebsite)
            if let url = URL(string: badWebsite) {
                _ = url.canonicalString // stops a Debug build if .canonicalString can't handle this URL string
            } else {
                ifDebugFatalError("\(fieldName) in \(fullName) holds \"\(badWebsite)\", which isn't a valid URL")
            }
        }
        return badWebsites
    }

}
