//
//  UrlComponents.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 13/07/2024.
//

public struct UrlComponents: Sendable {

    static let dataSourcePath = """
                                https://raw.githubusercontent.com/\
                                vdhamer/Photo-Club-Hub/\
                                main/JSON/
                                """

    var dataSourceFile: String // fgDeGender, can be overruled when testing
    let fileSubType: String // level2 (part of name)
    let fileType: String // json (actual file system type)

    var fullURLstring: String {
        // https://raw.githubusercontent.com/vdhamer/Photo-Club-Hub/main/ +
        // JSON/fgDeGender.level2.json
        return UrlComponents.dataSourcePath+dataSourceFile+"."+fileSubType+"."+fileType
    }

    var shortName: String {
        // fgDeGender.level2.json
        return dataSourceFile+"."+fileSubType+"."+fileType
    }

    // MARK: - Waalre

//    public static let waalre = UrlComponents( // TODO remove UrlComponents.waalre (etc)
//        dataSourceFile: "fgWaalre",
//        fileSubType: "level2",
//        fileType: "json"
//    )

    // MARK: - XampleMin

//    public static let xampleMin = UrlComponents(
//        dataSourceFile: "xampleMin",
//        fileSubType: "level2",
//        fileType: "json"
//    )

    // MARK: - XampleMax

//    public static let xampleMax = UrlComponents(
//        dataSourceFile: "xampleMax",
//        fileSubType: "level2",
//        fileType: "json"
//    )

    // MARK: - Bellus Imago

//    public static let bellusImago = UrlComponents(
//        dataSourceFile: "fcBellusImago",
//        fileSubType: "level2",
//        fileType: "json"
//    )

}
