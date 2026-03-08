//
//  SomeJsonReader.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 17/05/2025.
//

import CoreData // for NSManagedObjectContext

struct FetchAndProcessFile {

    private static let dataSourcePath: String = """
                                                https://raw.githubusercontent.com/\
                                                vdhamer/Photo-Club-Hub/\
                                                main/JSON/
                                                """

    init(bgContext: NSManagedObjectContext,
         fileSelector: FileSelector,
         fileType: String, fileSubType: String,
         useOnlyInBundleFile: Bool,
         isBeingTested: Bool,
         includeFilePath: [String],
         fileContentProcessor: @Sendable @escaping (_ bgContext: NSManagedObjectContext,
                                                    _ jsonData: String,
                                                    _ selectFile: FileSelector,
                                                    _ useOnlyInBundleFile: Bool,
                                                    _ isBeingTested: Bool,
                                                    _ includeFilePath: [String]) -> Void) {
        bgContext.perform { [self] in // run on requested background thread
            let nameWithSubtype = (fileSelector.fileName) + "." + fileSubType // e.g. "root.level1"

            var bundle: Bundle = Bundle.module // overwritten by Test Bundle if fileSelector.isBeingTested

            if fileSelector.isBeingTested {
                let testUrl = Bundle.module.bundleURL.deletingLastPathComponent().appending(
                    path: "Photo Club Hub Data_Photo Club Hub DataTests.bundle")
                let testBundle: Bundle? = Bundle(url: testUrl)
                guard testBundle != nil else {
                    fatalError("""
                               Failed to find URL to test bundle \
                               \(fileSelector.fileName).\(fileSubType).\(fileType) because testBundle is nil.
                               """)
                }
                bundle = testBundle!
            }

            let fileInBundleURL: URL? = bundle.url(forResource: nameWithSubtype, withExtension: fileType)
            guard fileInBundleURL != nil else {
                fatalError("""
                           Failed to find internal URL for \
                           \(fileSelector.fileName).\(fileSubType).\(fileType). Might be a filename or branch problem.
                           """)
            }

            let fileName = fileSelector.fileName
            let data = getData( // get the data from one of the two sources
                remoteFileURL: URL(string: Self.dataSourcePath + fileName // e.g., "fgDeGender" or "root"
                                   + "." + fileSubType // ".level2" or ".level1"
                                   + "." + fileType)!, // ".json"
                fileInBundleURL: fileInBundleURL!, // forced unwrap is safe (due to guard statement above)
                useOnlyInBundleFile: useOnlyInBundleFile
            )
            fileContentProcessor(bgContext, data, fileSelector, useOnlyInBundleFile, isBeingTested, includeFilePath)
        }
    }

    // try to fetch the online root.level0.json file, and if that fails fetch it from one of the app's bundles instead
    private func getData(remoteFileURL: URL,
                         fileInBundleURL: URL,
                         useOnlyInBundleFile: Bool) -> String {
        if let urlData = try? String(contentsOf: remoteFileURL, encoding: .utf8), !useOnlyInBundleFile {
            return urlData
        }
        print("Could not access online file \(remoteFileURL.relativeString). Trying in-app file instead.")

        if let bundleFileData = try? String(contentsOf: fileInBundleURL, encoding: .utf8) {
            return bundleFileData
        }
        // calling fatalError is ok for a compile-time constant (as defined above)
        fatalError("Cannot load Level 0 file \(remoteFileURL.relativeString)")
    }

}
