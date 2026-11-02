//
//  Level2JsonReaders+Helpers.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 04/01/2026.
//

import CoreData // for NSManagedObjectContext
import SwiftyJSON // for JSON struct
import CoreLocation // for CLLocationCoordinate2D

// The parts of reading a Level 2 file that deal with one element in the file: the club's identity, its coordinates,
// its optional fields, and each member. They run on the queue of `bgContext`, inside the reader's `perform` block.
extension Level2JsonReader {

    /// Loads one element of the `members` array: the person as a `Photographer`, and their membership of this club
    /// as a `MemberPortfolio`.
    ///
    /// A person is identified by their name alone, so the same name in two clubs' files is the same `Photographer`.
    /// That is why `givenName` and `familyName` are required (`infixName` is optional): without them, the member is
    /// skipped, and a Debug build stops.
    /// - Parameters:
    ///   - bgContext: The background context the whole Level 2 file is loaded into.
    ///   - member: One element of the file's `members` array.
    ///   - club: The club whose Level 2 file this is.
    static func loadMember(bgContext: NSManagedObjectContext,
                           member: JSON,
                           club: Organization) {
        // MARK: - /members/member/name
        guard member["name"].exists(),
              member["name"]["givenName"].exists(),
              // if member["name"]["givenName"] doesn't exist, SwiftyJSON returns ""
              member["name"]["familyName"].exists() else { // check for mandatory fields
            ifDebugFatalError("Missing or incomplete member/name data in \(club.id.fullName)")
            return
        }
        let givenName: String = member["name"]["givenName"].stringValue
        let infixName: String = member["name"]["infixName"].stringValue
        let familyName: String = member["name"]["familyName"].stringValue
        print("""
              Member "\(givenName) \
              \(infixName=="" ? "" : infixName + " ")\
              \(familyName)" found in \(club.id.fullName)
              """)
        let photographer = Photographer.findCreateUpdate(context: bgContext,
                                                         personName: PersonName(
                                                             givenName: givenName,
                                                             infixName: infixName, // may be ""
                                                             familyName: familyName
                                                         ),
                                                         optionalFields: PhotographerOptionalFields()) // filled later

        let memberPortfolio: MemberPortfolio
        if member["optional"].exists() { // could contain photographerOptionalFields, memberOptionalFields, or both.
            memberPortfolio = Level2JsonReader.loadPhotographerAndMemberOptionals(bgContext: bgContext,
                                                                                  jsonOptionals: member["optional"],
                                                                                  photographer: photographer,
                                                                                  club: club)
        } else {
            memberPortfolio = MemberPortfolio.findCreateUpdate(bgContext: bgContext,
                                                               organization: club,
                                                               photographer: photographer,
                                                               optionalFields: MemberOptionalFields(
                                                                    memberRolesAndStatus: MemberRolesAndStatus(
                                                                                                jsonRoles: [:],
                                                                                                jsonStatus: [:])
                                                               )
            )
        }
        memberPortfolio.refreshFirstImage()
    }

    /// Merges the `optional` block of the file's `club` element with the club's stored record.
    ///
    /// The club knows its own details best, so a value here overrules the one from the club's Level 1 entry. There are
    /// exceptions:
    /// - `level2URL` is ignored, so that a Level 2 file can't redirect where its own club's data is loaded from.
    /// - `logbook` and `badWebsites` are ignored until Data#92, and stop a Debug build (as a pretty loud warning).
    /// - A `website` that the Level 1 entry lists in `badWebsites` is not stored (`Organization.update()`).
    ///
    /// The coordinates aren't set here: the caller has already loaded the file's `coordinates`.
    /// - Parameters:
    ///   - bgContext: The background context the whole Level 2 file is loaded into.
    ///   - jsonOptionals: The `optional` block of the file's `club` element.
    ///   - club: The club whose Level 2 file this is.
    static func loadClubOptionals(bgContext: NSManagedObjectContext,
                                  jsonOptionals: JSON,
                                  club: Organization) {
        // Until Data#92, only a Level 1 file can supply these, so this reader ignores them.
        // Ignoring them silently would lose what the club wrote, so for now they stop a Debug build.
        for key in ["logbook", "badWebsites"] where jsonOptionals[key].exists() {
            ifDebugFatalError("The Level 2 file of \(club.fullName) has a \(key). Only Level 1 currently supports this")
        }

        let clubWebsite = jsonOptionals["website"].exists() ? URL(string: jsonOptionals["website"].stringValue) : nil
        let wikipedia: URL? = Level2JsonReader.jsonOptionalsToURL(jsonOptionals: jsonOptionals, key: "wikipedia")
        // level2URL is deliberately ignoring to avoid possibility of overruling what is stated in Level 1 file
        let localizedRemarks: [JSON] = jsonOptionals["remark"].arrayValue // empty array if missing
        let maintainerEmail: String? = jsonOptionals["maintainerEmail"].exists() ?
            jsonOptionals["maintainerEmail"].stringValue : nil
        let fotobondClubNumberID: Int16? = jsonOptionals["nlSpecific"]["fotobondNumber"].exists() ? // FotobondNL clubid
            jsonOptionals["nlSpecific"]["fotobondNumber"].int16Value : nil

        _ = Organization.findCreateUpdate(context: bgContext,
                                          organizationTypeEnum: OrganizationTypeEnum.club,
                                          idPlus: OrganizationIdPlus(fullName: club.fullName, town: club.town,
                                                                     nickname: club.nickName),
                                          coordinates: club.coordinates,
                                          optionalFields: OrganizationOptionalFields(
                                              organizationWebsite: clubWebsite,
                                              wikipedia: wikipedia,
                                              fotobondClubNumber: FotobondClubNumber(id: fotobondClubNumberID),
                                              maintainerEmail: maintainerEmail,
                                              localizedRemarks: localizedRemarks
                                              )
        )
    }

    /// Loads a member's `optional` block, which contains two kinds of fields:
    /// - about the person, stored in `Photographer`: `birthday`, being deceased, `website`, `photographerImage` and
    ///   `expertises`. Another club's file can supply these too, but the info is shared across clubs.
    /// - about this membership, stored on `MemberPortfolio`: `featuredImage`, `level3URL`, `roles`, `status`, the
    ///   Fotobond member number, and membership start/end dates.
    ///
    /// A malformed date stops a Debug build (see `String.extractDate()`). A Release build leaves that date unset.
    /// - Parameters:
    ///   - bgContext: The background context the whole Level 2 file is loaded into.
    ///   - jsonOptionals: The member's `optional` block.
    ///   - photographer: The person, already found or created by name.
    ///   - club: The club whose Level 2 file this is.
    /// - Returns: The member's portfolio in this club, found or created.
    private static func loadPhotographerAndMemberOptionals(bgContext: NSManagedObjectContext,
                                                           jsonOptionals: JSON,
                                                           photographer: Photographer,
                                                           club: Organization) -> MemberPortfolio {

        let memberRolesAndStatus = MemberRolesAndStatus(jsonRoles: jsonOptionals["roles"],
                                                        jsonStatus: jsonOptionals["status"])

        let birthday: String? = jsonOptionals["birthday"].exists() ? jsonOptionals["birthday"].stringValue : nil
        let photographerWebsite: URL? = Level2JsonReader.jsonOptionalsToURL(jsonOptionals: jsonOptionals,
                                                                            key: "website")
        let photographerImage: URL? = Level2JsonReader.jsonOptionalsToURL(jsonOptionals: jsonOptionals,
                                                                          key: "photographerImage")
        let featuredImage: URL? = Level2JsonReader.jsonOptionalsToURL(jsonOptionals: jsonOptionals,
                                                                      key: "featuredImage")
        let level3URL: URL? = Level2JsonReader.jsonOptionalsToURL(jsonOptionals: jsonOptionals,
                                                                  key: "level3URL")

        let membershipStartDate: Date? = jsonOptionals["membershipStartDate"].exists() ?
            jsonOptionals["membershipStartDate"].stringValue.extractDate() : nil
        let membershipEndDate: Date? = jsonOptionals["membershipEndDate"].exists() ?
            jsonOptionals["membershipEndDate"].stringValue.extractDate() : nil

        let photographerExpertises: [JSON] = jsonOptionals["expertises"].arrayValue

        let fotobondMemberNumber: FotobondMemberNumber? = jsonOptionals["nlSpecific"]["fotobondNumber"].exists() ?
            FotobondMemberNumber(id: jsonOptionals["nlSpecific"]["fotobondNumber"].int32Value) : nil

        // some attributes are at the Photographer level...
        _ = Photographer.findCreateUpdate(context: bgContext,
                                          personName: PersonName(givenName: photographer.givenName,
                                                                 infixName: photographer.infixName,
                                                                 familyName: photographer.familyName),
                                          optionalFields: PhotographerOptionalFields(
                                              bornDT: birthday?.extractDate(),
                                              isDeceased: memberRolesAndStatus.isDeceased(),
                                              photographerWebsite: photographerWebsite,
                                              photographerImage: photographerImage,
                                              photographerExpertises: photographerExpertises
                                              )
                                          )

        // ...while some attributes are at the Photographer-as-Member-of-club level (instead of Photographer level)
        return MemberPortfolio.findCreateUpdate(
            bgContext: bgContext,
            organization: club,
            photographer: photographer,
            removeMember: false, // remove records for members that no longer on list
            optionalFields: MemberOptionalFields(
                featuredImage: featuredImage,
                featuredImageThumbnail: featuredImage,
                level3URL: level3URL, // address of portfolio data for this member
                memberRolesAndStatus: memberRolesAndStatus,
                fotobondMemberNumber: fotobondMemberNumber,
                membershipStartDate: membershipStartDate,
                membershipEndDate: membershipEndDate
            )
        )

    }

    /// Reads one URL from an `optional` block.
    /// - Returns: nil if `key` is absent, isn't a string, or isn't a valid URL.
    ///   All three mean "no value", meaing they don't change what is already stored.
    private static func jsonOptionalsToURL(jsonOptionals: JSON, key: String) -> URL? {
        guard jsonOptionals[key].exists() else { return nil }
        guard let string = jsonOptionals[key].string else { return nil }
        return URL(string: string) // returns nil if the string doesn’t represent a valid URL
    }

    /// Checks that file's `idPlus` is complete, and that the file is about the club that requested the file loading.
    ///
    /// `fullName`, `town` and `nickName` are all required. `fullName` and `nickName` must match `targetIdPlus`, and so
    /// must `town` except in tests. Anything else stops a Debug build. A Release build skips the whole Level 2 file.
    /// - Parameters:
    ///   - jsonClub: The file's `club` element.
    ///   - targetIdPlus: The club the file will be loaded for.
    ///   - isBeingTested: If true, the town isn't compared, so tests can load a fixture under any town.
    /// - Returns: The file's own `idPlus` if it is complete and expected club, or nil otherwise.
    static func checkIdPlus(jsonClub: JSON,
                            targetIdPlus: OrganizationIdPlus,
                            isBeingTested: Bool) -> OrganizationIdPlus? {

        // MARK: - /club/idPlus loading
        guard jsonClub["idPlus"].exists() else {
            ifDebugFatalError("Cannot find `idPlus` keyword for club \(targetIdPlus.fullName)")
            return nil
        }
        let jsonIdPlus: JSON = jsonClub["idPlus"]

        // MARK: - /club/idPlus/fullName
        guard jsonIdPlus["fullName"].exists() else {
            ifDebugFatalError("Cannot find `fullName` keyword in idPlus for club \(targetIdPlus.fullName)")
            return nil
        }
        // MARK: - /club/idPlus/town
        guard jsonIdPlus["town"].exists() else {
            ifDebugFatalError("Cannot find `town` keyword in idPlus for club \(targetIdPlus.fullName)")
            return nil
        }
        // MARK: - /club/idPlus/nickName
        guard jsonIdPlus["nickName"].exists() else {
            ifDebugFatalError("Cannot find `nickName` keyword in idPlus for club \(targetIdPlus.fullName)")
            return nil
        }
        // MARK: - /club/idPlus check if this is the club we were expecting
        let idPlus = OrganizationIdPlus(fullName: jsonIdPlus["fullName"].stringValue, // idPlus found _inside_ JSON file
                                        town: jsonIdPlus["town"].stringValue,
                                        nickname: jsonIdPlus["nickName"].stringValue)
        guard idPlus.fullName == targetIdPlus.fullName &&
              idPlus.nickname == targetIdPlus.nickname else {// does file contain the expected club?
            ifDebugFatalError("""
                              Warning: JSON file expecting to contain club \
                              \(targetIdPlus.fullName) (\(targetIdPlus.nickname)) \
                              contains club \(idPlus.fullName) (\(idPlus.nickname)) instead.
                              """)
            return nil // in non-debug software, just skip loading this Level 2 file
        }

        if isBeingTested == false {
            guard idPlus.town == targetIdPlus.town else { // expected town?
                ifDebugFatalError("""
                                  Warning: there is a mismatch for the Town of \(targetIdPlus.fullName): \
                                  the in-file town is \(idPlus.town) but \(targetIdPlus.town) was expected.
                                  """)
                return nil // in non-debug software, just skip loading this Level 2 file
            }
        }

        return idPlus
    }

    /// Reads the club's `coordinates`, which a Level 2 file must contain.
    /// The caller lets them overrule the coordinates from the club's Level 1 entry.
    /// This allows a club to move its pin on the map without the help needed to update a Level 1 files they don't own.
    /// - Parameters:
    ///   - jsonClub: The file's `club` element.
    ///   - targetIdPlus: The club the file was loaded for, used in error messages.
    /// - Returns: The coordinates, or nil if `coordinates`, `latitude` or `longitude` is missing. That also stops a
    ///   Debug build.
    static func loadClubCoordinates(jsonClub: JSON, targetIdPlus: OrganizationIdPlus) ->
        CLLocationCoordinate2D? {

        guard jsonClub["coordinates"].exists() else {
            ifDebugFatalError("Cannot find `coordinates` keyword for club \(targetIdPlus.fullName)")
            return nil
        }

        guard jsonClub["coordinates"]["latitude"].exists() && jsonClub["coordinates"]["longitude"].exists() else {
            ifDebugFatalError("`coordinates` keyword missing `latitude` or `longitude` for \(targetIdPlus.fullName)")
            return nil
        }

        let coordinates: CLLocationCoordinate2D =
            CLLocationCoordinate2D(latitude: jsonClub["coordinates"]["latitude"].doubleValue,
                                   longitude: jsonClub["coordinates"]["longitude"].doubleValue)
        return coordinates
    }

}
