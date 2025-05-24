//
//  FileSelector.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 24/05/2025.
//

// create by providing either an OrganizationIdPlus struct, or a file name
// But you are not allowed to provide both.
struct FileSelector {
    let organizationIdPlus: OrganizationIdPlus?
    private let providedFileName: String?

    init(organizationIdPlus: OrganizationIdPlus) {
        self.organizationIdPlus = organizationIdPlus
        self.providedFileName = nil
    }

    init(fileName: String) {
        self.providedFileName = fileName
        self.organizationIdPlus = nil
    }

    @available(*, unavailable)
    init(organizationIdPlus: OrganizationIdPlus, fileName: String) {
        ifDebugFatalError("Calls to SelectFile.init() must supply one parameter only.")
        self.init(organizationIdPlus: organizationIdPlus) // try to continue although there is an error
    }

    var fileName: String {
        if providedFileName != nil {
            return providedFileName!
        } else {
            return organizationIdPlus!.nickname
        }
    }
}
