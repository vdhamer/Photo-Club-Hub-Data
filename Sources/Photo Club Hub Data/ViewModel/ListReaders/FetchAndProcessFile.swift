//
//  SomeJsonReader.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 17/05/2025.
//

import CoreData // for NSManagedObjectContext

struct fetchAndProcessFile: Sendable {

    private static let dataSourcePath: String = """
                                                https://raw.githubusercontent.com/\
                                                vdhamer/Photo-Club-Hub/\
                                                main/JSON/
                                                """

    init(bgContext: NSManagedObjectContext,
         useOnlyFile: Bool,
         filename: String,  // special files can be used for unit testing
         fileSubType: String,
         fileType: String,
         processJson: @escaping (_ bgContext: NSManagedObjectContext,
                                 _ jsonData: String,
                                 _ dataSourceFile: String) -> Void) {
        bgContext.perform { [self] in // switch to supplied background thread
            let name = filename + "." + fileSubType

            let bundle: Bundle = Bundle.module // bundle may be a package rather than Bundle.main
            let fileInBundleURL: URL? = bundle.url(forResource: name, withExtension: "." + fileType)
            guard fileInBundleURL != nil else {
                fatalError("""
                           Failed to find URL to the file \(name).\(fileType) \
                           in bundle \(bundle.bundleIdentifier ?? "")
                           """)
            }
            let data = self.getData( // get the data from one of the two sources
                fileURL: URL(string: Self.dataSourcePath + filename + "." +
                             fileSubType + "." + fileType)!,
                fileInBundleURL: fileInBundleURL!, // protected by guard statement
                useOnlyFile: useOnlyFile
            )
            processJson(bgContext, data, filename)
        }
    }

    // try to fetch the online root.level0.json file, and if that fails fetch it from one of the app's bundles instead
    fileprivate func getData(fileURL: URL,
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

}
