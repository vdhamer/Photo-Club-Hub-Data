//
//  LocalizedExpertiseResultLists.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 09/06/2025.
//

import CoreData // for NSManagedObjectContext

let maxExpertisesPerMember: Int = 2

// Used to provide the UI and HTML with pairs of lists with Exertise records with localized names
public struct LocalizedExpertiseResultLists {

    public var supported = LocalizedExpertiseResultList(isSupported: true, list: [])
    public var temporary = LocalizedExpertiseResultList(isSupported: false, list: [])

    public init(supportedList: [LocalizedExpertiseResult], temporaryList: [LocalizedExpertiseResult]) {
        supported = LocalizedExpertiseResultList(isSupported: true, list: supportedList)
        temporary = LocalizedExpertiseResultList(isSupported: false, list: temporaryList)
    }

    // `isoCode` selects the language of the localized names. When nil (e.g. the iOS app), the device's
    // system language is used; HTML generation passes the target page's language so each (club × language)
    // page renders its expertise tags in the correct language (see ticket #216).
    public init(moc: NSManagedObjectContext,
                isoCode: String? = nil,
                _ photographerExpertises: Set<PhotographerExpertise>) {

        // Use init(supportedList:temporaryList) to get access to the icons
        var resultLERLs = LocalizedExpertiseResultLists.init(supportedList: [], temporaryList: [])

        // Step 1. Translate expertises to appropriate language
        var translated: [LocalizedExpertiseResult] = [] // start with empty array
        for photographerExpertise in photographerExpertises { // choose suitable language
            translated.append(photographerExpertise.expertise.selectedLocalizedExpertise(isoCode: isoCode))
        }

        // Step 2. Sort based on selected language.  Has special behavior for expertises without translation
        let sorted: [LocalizedExpertiseResult] = translated.sorted() // note dedicated LocalizedExpertiseResult.<() func

        // Step 3. Clip size to maxExpertisesPerMember Expertises
        var clipped: [LocalizedExpertiseResult] = [] // start with empty array
        if sorted.count > 0 {
            for index in 0...min(maxExpertisesPerMember-1, sorted.count-1) {
                clipped.append(sorted[index]) // copy the first few sorted LocalizedExpertiseResult elements
            }
        }

        // Step 4. Split list of photographer's expertises into 2 parts: supported and temporary
        for item in clipped {
            if item.isSupported {
                resultLERLs.supported.list.append(item)
            } else {
                resultLERLs.temporary.list.append(LocalizedExpertiseResult(localizedExpertise:
                                                                                item.localizedExpertise, id: item.id))
            }
        }

        // Step 5. warn if there are more expertises than allowed
        if sorted.count > maxExpertisesPerMember { // if list overflows, add a warning
            resultLERLs.temporary.list.append(makeOverflowWarning(moc: moc, isoCode: isoCode, sorted: sorted))
        }

        // Step 6. remove delimeter after last element
        if !resultLERLs.supported.list.isEmpty {
            resultLERLs.supported.list[resultLERLs.supported.list.count-1].delimiterToAppend = "" // was ","
        }
        if !resultLERLs.temporary.list.isEmpty {
            resultLERLs.temporary.list[resultLERLs.temporary.list.count-1].delimiterToAppend = ""
        }

        self.supported.list = resultLERLs.supported.list
        self.temporary.list = resultLERLs.temporary.list
    }

    // Builds the "Too many expertises" warning element shown when a member has more expertises than allowed.
    private func makeOverflowWarning(moc: NSManagedObjectContext,
                                     isoCode: String?,
                                     sorted: [LocalizedExpertiseResult]) -> LocalizedExpertiseResult {
        let moreExpertise = Expertise.findCreateUpdateTemporary(
                                      context: moc,
                                      id: String(localized: "Too many expertises",
                                                 table: "PhotoClubHubData", bundle: Bundle.photoClubHubDataModule,
                                                 comment: "Shown when too many expertises are found"),
                                      names: [],
                                      usages: [] )
        let moreLocalizedExpertise = moreExpertise.selectedLocalizedExpertise(isoCode: isoCode)
        do { // new expertises are loaded by Level0Loader or Level2Loader. This pseudo-expertise is an exception.
            if moc.hasChanges {
                try moc.save()
            }
        } catch {
            ifDebugFatalError("Failed to save \"too many expertises\" as an Expertise: \(error)")
        }
        return LocalizedExpertiseResult(localizedExpertise: moreLocalizedExpertise.localizedExpertise,
                                        id: moreExpertise.id,
                                        customHint: customHint(localizedExpertiseResults: sorted))
    }

    private func customHint(localizedExpertiseResults: [LocalizedExpertiseResult]) -> String {
        var hint: String = ""
        let temp = LocalizedExpertiseResultLists(supportedList: [], temporaryList: [])

        for localizedExpertiseResult in localizedExpertiseResults {
            if localizedExpertiseResult.localizedExpertise != nil {
                hint.append(temp.supported.icon + " " + localizedExpertiseResult.localizedExpertise!.name + " ")
            } else {
                hint.append(temp.temporary.icon + " " + localizedExpertiseResult.id + " ")
            }
        }

        return hint.trimmingCharacters(in: CharacterSet(charactersIn: " "))
    }

    public func getIconString(isSupported: Bool) -> String {
        let temp = LocalizedExpertiseResultLists(supportedList: [], temporaryList: [])
        return isSupported ? temp.supported.icon : temp.temporary.icon
    }
}
