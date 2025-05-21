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
         organizationIdPlus: OrganizationIdPlus?, // level2 describes individual clubs
         fileName: String?, // level0 and level1 are not club-specific, so provide either organizIdPlus or fileName
         fileType: String, fileSubType: String,
         useOnlyInBundleFile: Bool,
         fileContentProcessor: @escaping (_ bgContext: NSManagedObjectContext,
                                          _ jsonData: String,
                                          _ organizationIdPlus: OrganizationIdPlus?,
                                          _ fileName: String?) -> Void) {
        guard organizationIdPlus != nil || fileName != nil else {
            fatalError("Either organizationIdPlus or fileName must be provided")
        }
        bgContext.perform { [self] in // run on requested background thread
            let nameWithSubtype = (organizationIdPlus?.nickname ?? fileName!) + "." + fileSubType // e.g. "root.level0"

            let bundle: Bundle = Bundle.module // bundle may be a package rather than Bundle.main
            let fileInBundleURL: URL? = bundle.url(forResource: nameWithSubtype, withExtension: "." + fileType)
            guard fileInBundleURL != nil else {
                fatalError("""
                           Failed to find URL to the file \
                           \(organizationIdPlus?.nickname ?? fileName ?? "fileName?" ).\(fileSubType).\(fileType) \
                           in bundle \(bundle.bundleIdentifier ?? "bundle?")
                           """)
            }

            let optionalName: String? = organizationIdPlus?.nickname ?? fileName // one of them is not nil (guard)
            let data = getData( // get the data from one of the two sources
                remoteFileURL: URL(string: Self.dataSourcePath + optionalName! // "fgDeGender" or "root"
                                   + "." + fileSubType // ".level2" or ".level1"
                                   + "." + fileType)!, // ".json"
                fileInBundleURL: fileInBundleURL!, // forced unwrap is safe (due to guard statement above)
                useOnlyInBundleFile: useOnlyInBundleFile
            )
            fileContentProcessor(bgContext, data, organizationIdPlus, fileName)
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
