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
         filename: String, fileSubType: String, fileType: String,
         useOnlyInBundleFile: Bool,
         fileContentProcessor: @escaping (_ bgContext: NSManagedObjectContext,
                                          _ jsonData: String,
                                          _ fileName: String) -> Void) {
        bgContext.perform { [self] in // run on requested background thread
            let name = filename + "." + fileSubType // e.g. "root.level0"

            let bundle: Bundle = Bundle.module // bundle may be a package rather than Bundle.main
            let fileInBundleURL: URL? = bundle.url(forResource: name, withExtension: "." + fileType)
            guard fileInBundleURL != nil else {
                fatalError("""
                           Failed to find URL to the file \(name).\(fileType) \
                           in bundle \(bundle.bundleIdentifier ?? "")
                           """)
            }

            let data = self.getData( // get the data from one of the two sources
                remoteFileURL: URL(string: Self.dataSourcePath + filename + "." +
                                   fileSubType + "." + fileType)!,
                fileInBundleURL: fileInBundleURL!, // forced unwrap is safe due to by guard statement
                useOnlyInBundleFile: useOnlyInBundleFile
            )
            fileContentProcessor(bgContext, data, filename)
        }
    }

    // try to fetch the online root.level0.json file, and if that fails fetch it from one of the app's bundles instead
    fileprivate func getData(remoteFileURL: URL,
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
