//
//  Level0JsonReader.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 12/03/2025.
//

import CoreData // for NSManagedObjectContext
import SwiftyJSON // for JSON struct

private let dataSourcePath: String = """
                                     https://raw.githubusercontent.com/\
                                     vdhamer/Photo-Club-Hub/\
                                     main/JSON/
                                     """
private let dataSourceFile: String = "root"
private let fileSubType = "level0" // level0 is part of file name, the extension is "json" rather than "level0"
private let fileType = "json"

// see JSON/root.level0.json for a syntax example

public class Level0JsonReader {

    public init(bgContext: NSManagedObjectContext,
                useOnlyFile: Bool = false,
                overrulingDataSourceFile: String? = nil) {

        bgContext.perform { // switch to supplied background thread
            let overruledDataSourceFile: String = overrulingDataSourceFile ?? dataSourceFile
            let name = overruledDataSourceFile + "." + fileSubType

            let bundle: Bundle = Bundle.module // instead of bundle = Bundle.main
            let fileInBundleURL: URL? = bundle.url(forResource: name, withExtension: "." + fileType)
            guard fileInBundleURL != nil else {
                fatalError("""
                           Failed to find URL to the file \(name).\(fileType) \
                           in bundle \(bundle.bundleIdentifier ?? "")
                           """)
            }
            let data = self.getData( // get the data from one of the two sources
                fileURL: URL(string: dataSourcePath + overruledDataSourceFile + "." +
                             fileSubType + "." + fileType)!,
                fileInBundleURL: fileInBundleURL!, // protected by guard statement
                useOnlyFile: useOnlyFile
            )
            self.readRootLevel0Json(bgContext: bgContext,
                                    jsonData: data)
        }

    }

    // try to fetch the online root.level0.json file, and if that fails use a copy from the app's bundle instead
    fileprivate func getData(fileURL: URL, // TODO needs checking/cleanup
                             fileInBundleURL: URL,
                             useOnlyFile: Bool) -> String {
        if let urlData = try? String(contentsOf: fileURL, encoding: .utf8), !useOnlyFile {
            return urlData
        }
        print("Could not access online file \(fileURL.relativeString). Trying in-app file instead.")

        if let bundleFileData = try? String(contentsOf: fileInBundleURL, encoding: .utf8) {
            return bundleFileData
        }
        // calling fatalError is ok for a compile-time constant (as defined above)
        fatalError("Cannot load Level 0 file \(fileURL.relativeString)")
    }

    fileprivate func readRootLevel0Json(bgContext: NSManagedObjectContext,
                                        jsonData: String) {

        ifDebugPrint("\nWill read Level 0 file (\(dataSourceFile)) with standard keywords and languages in background.")

        // hand the data to SwiftyJSON to parse
        let jsonRoot = JSON(parseJSON: jsonData) // get entire JSON file

        // parse Keywords section of file
        let jsonKeywords: [JSON] = jsonRoot["keywords"].arrayValue

        parseKeywords(bgContext: bgContext, jsonKeywords: jsonKeywords)
        print("\(jsonKeywords.count) Keywords found")

        // parse Language section of file
        let jsonLanguages: [JSON] = jsonRoot["languages"].arrayValue

        parseLanguages(bgContext: bgContext, jsonLanguages: jsonLanguages)

        do { // saving may not be necessary because every organization is saved separately
            if bgContext.hasChanges { // optimization recommended by Apple
                try bgContext.save() // persist contents of entire root.Level1.json file
            }
        } catch {
            ifDebugFatalError("Failed to save changes to Core Data: \(error)",
                              file: #fileID, line: #line)
            // in release mode, the failed database update is only logged. App doesn't stop.
            ifDebugPrint("Failed to save JSON Keyword changes in background")
            return
        }

        ifDebugPrint("Completed readRootLevel0Json() in background")
    }

    private func parseLanguages(bgContext: NSManagedObjectContext, jsonLanguages: [JSON]) {
        for jsonLanguage in jsonLanguages {
            guard jsonLanguage["isoCode"].exists(),
                  jsonLanguage["languageNameEN"].exists() else {
                ifDebugFatalError("Language doesn't have an isoCode or translated name", file: #fileID, line: #line)
                continue
            }

            let isoCode = jsonLanguage["isoCode"].stringValue
            let languageNameEN = jsonLanguage["languageNameEN"].stringValue

            let language = Language.findCreateUpdate(context: bgContext,
                                                     isoCode: isoCode,
                                                     nameENOptional: languageNameEN)
            print("Language <\(language.isoCodeAllCaps)> found")
        }
    }

    private func parseKeywords(bgContext: NSManagedObjectContext, jsonKeywords: [JSON]) {
        for jsonKeyword in jsonKeywords {
            guard jsonKeyword["idString"].exists() else {
                ifDebugFatalError("Keyword doesn't have an idString", file: #fileID, line: #line)
                continue  // if it doesn't exist, skip the keyword
            }
            let idString = jsonKeyword["idString"].stringValue

            guard jsonKeyword["name"].exists() else {
                ifDebugFatalError("Keyword doesn't have localized representations", file: #fileID, line: #line)
                continue  // if it doesn't exist, skip the keyword
            }
            let jsonKeywordName = jsonKeyword["name"].arrayValue // entire dictionary of localized names for the keyword

            // we insist on having at least one language for which jsonKeyword has a localized name
            guard jsonKeywordName.count > 0,
                  jsonKeywordName[0]["language"].exists(),
                  jsonKeywordName[0]["localizedString"].exists() else {
                ifDebugFatalError("Keyword doesn't have any localized representations", file: #fileID, line: #line)
                continue  // if it doesn't exist, skip the keyword (note that it even skips the "usage" array)
            }

            let jsonKeywordOptionals = jsonKeyword["optional"] // rest will be empty if not found
            let jsonUsage = jsonKeywordOptionals["usage"].arrayValue

            let keyword = Keyword.findCreateUpdateStandard(context: bgContext,
                                                           id: idString,
                                                           name: jsonKeywordName,
                                                           usage: jsonUsage)
            print("Keyword <\(keyword.id)> with \(jsonKeywordName.count) localized name(s) found")
        }
    }

}
