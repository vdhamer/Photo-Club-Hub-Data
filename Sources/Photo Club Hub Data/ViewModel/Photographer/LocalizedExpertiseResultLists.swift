//
//  LocalizedKeywordResultLists.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 09/06/2025.
//

// Used to provide UI with pairs of lists with Exertise records with localized names
public struct LocalizedExpertiseResultLists {

    public init(standardList: [LocalizedKeywordResult], nonstandardList: [LocalizedKeywordResult]) {
        standard = LocalizedExpertiseResultList(icon: "🏵️", list: standardList)
        nonstandard = LocalizedExpertiseResultList(icon: "🪲", list: nonstandardList)
    }

    public var standard: LocalizedExpertiseResultList
    public var nonstandard: LocalizedExpertiseResultList

}

public struct LocalizedExpertiseResultList {

    public init(isStandard: Bool, list: [LocalizedKeywordResult]) {
        self.icon = isStandard ? "🏵️" : "🪲"
        self.list = list
    }

    public let icon: String // cannot be modified, icon is a single Unicode character
    public var list: [LocalizedKeywordResult]

}
