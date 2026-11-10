//
//  Organization+ComputedProperties.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 03/07/2021.
//

import CoreLocation // needed for coordinate translation

extension Organization {

    // MARK: - getters and setters

	public var members: Set<MemberPortfolio> {
		get { (members_ as? Set<MemberPortfolio>) ?? [] }
		set { members_ = newValue as NSSet }
	}

    public var organizationType: OrganizationType {
        @MainActor
        get { // careful: cannot read organizationType on background thread if database still contains nil
            if organizationType_ != nil {
                return organizationType_! // organizationType_ cannot be nil at this point
            } else {
                if isUsable { // something is fundamentally wrong if this happens to a live Organization
                    ifDebugFatalError( "Error because organizationType is nil", file: #fileID, line: #line )
                } // a deleted Organization legitimately has no organizationType_ (issue #802): use the fallback
                let persistenceController = PersistenceController.shared // for Core Data
                let viewContext = persistenceController.container.viewContext // requires @MainActor
                return OrganizationType.findCreateUpdate( // organizationType is CoreData NSManagedObject
                    context: viewContext, // requires @MainActor
                    orgTypeName: OrganizationTypeEnum.unknown.rawValue
                )
            }
        }

        set {
            if organizationType_ != newValue { // avoid unnecessarily dirtying context
                organizationType_ = newValue
            }
        }
    }

	public var fullName: String {
		get { return fullName_ ?? "DefaultPhotoClubName" }
		set { fullName_ = newValue }
	}

    /* https://
    stackoverflow.com/questions/25485273/swift-coredata-cannot-automatically-set-optional-attribute-on-generated-nsman
    */
    public var fotobondClubNumber: FotobondClubNumber? {
        get {
            if let raw: NSNumber = fotobondClubNumber_ as NSNumber? {
                return FotobondClubNumber(id: Int16(truncating: raw))
            } else {
                return FotobondClubNumber(id: nil as Int16?)
            }
        }
        set {
            if let newValue, newValue.id != nil {
                fotobondClubNumber_ = newValue.id! as NSNumber
            }
        }
    }

    // Appends " (\(town))" to \(fullName) unless \(town) is already part of \(fullName).
    // The following cases are tested in OrganizationTest:
    // "Fotogroep Waalre" and "Aalst" returns "Fotogroep Waalre (Aalst)"
    // "Fotogroep Waalre" and "Waalre" returns "Fotogroep Waalre"
    // "Fotogroep Waalre" and "waalre" returns "Fotogroep Waalre (waalre)" because matching is case-sensitive
    // "Fotogroep Waalre" and "to" returns "Fotogroep Waalre (to)"
    // "Fotogroep Waalre" and "Waal" returns "Fotogroep Waalre (Waal)" if you use NLP-based word matching
    // "Fotoclub Den Dungen" and "Den Dungen" returns "Fotoclub Den Dungen"
    // "Fotokring Sint-Michielsgestel" and "Sint-Michielsgestel" returns "Fotokring Sint-Michielsgestel"
    // Also the iOS Clubs tab's section id (#802), so it uses the stored town only. Users see fullNameLocalizedTown.
    @objc public var fullNameTown: String { // @objc needed for SectionedFetchRequest's sectionIdentifier
        if fullNameContains(town: town) {
            return fullName // fullname "Fotogroep Waalre" and town "Waalre" returns "Fotogroep Waalre"
        }
        return "\(fullName) (\(town))" // fullname "Fotogroep Aalst" with "Waalre" returns "Fotogroep Aalst (Waalre)"
    }

    /// Returns `fullName` followed by the town in `language`, as users should see it.
    ///
    /// The name itself is never translated. The town is left out when `fullName` already contains either the
    /// stored `town` or the localized one, so "Fotomuseum Den Haag" gets no suffix in any language (Data#88).
    /// The town comes from `localizedTown(for:)`, with the stored `town` standing in when that gives the
    /// "Town?" placeholder, so a club header or page title never shows the placeholder.
    ///
    /// | `fullName`          | `town`   | localized town   | Returns                    |
    /// |---------------------|----------|------------------|----------------------------|
    /// | Museum Ludwig       | Köln     | Keulen (nl)      | Museum Ludwig (Keulen)     |
    /// | Museum Ludwig       | Köln     | Cologne (en)     | Museum Ludwig (Cologne)    |
    /// | Fotomuseum Den Haag | Den Haag | The Hague (en)   | Fotomuseum Den Haag        |
    /// | Museum Cologne      | Köln     | Cologne (en)     | Museum Cologne             |
    /// | Museum Cologne      | Köln     | Keulen (nl)      | Museum Cologne (Keulen)    |
    /// | Fotogroep Waalre    | Aalst    | no row yet       | Fotogroep Waalre (Aalst)   |
    /// | Fotogroep Waalre    | Aalst    | "Town?"          | Fotogroep Waalre (Aalst)   |
    ///
    /// Each row is covered by a test in OrganizationTest.
    /// Unlike `fullNameTown`, this is not an identity: it changes with the language and with geocoding.
    public func fullNameLocalizedTown(for language: Language) -> String {
        let translatedTown: String = localizedTown(for: language)
        let shownTown: String = translatedTown == LocalizedAddress.unknownTown ? town : translatedTown
        if fullNameContains(town: town) || fullNameContains(town: shownTown) {
            return fullName
        }
        return "\(fullName) (\(shownTown))"
    }

    // Whether `fullName` already names `town`, so that appending " (town)" would repeat it.
    // A one-word town must match a whole word ("Waal" is not in "Fotogroep Waalre"), using NLP to find the words.
    // A town of several words or with a hyphen counts when it occurs anywhere ("Fotoclub Den Dungen"),
    // because NLP compares one word at a time and so never matches it.
    // Both checks are case-sensitive: "waalre" is not in "Fotogroep Waalre".
    private func fullNameContains(town: String) -> Bool {
        if fullName.containsWordUsingNLP(targetWord: town) {
            return true
        }
        return fullName.contains(town) && (town.contains(" ") || town.contains("-"))
    }

    public var id: OrganizationID { // public because needed for Identifiable protocol
        OrganizationID(fullName: self.fullName, town: self.town)
    }

    public var nickName: String {
        get { return nickName_ ?? "Name?" }
        set { nickName_ = newValue }
    }

    public var maintainerEmail: String? {
        get { // https://softwareengineering.stackexchange.com/questions/32578/sql-empty-string-vs-null-value
            if maintainerEmail_ == "" || maintainerEmail_ == nil {
                return nil
            } else {
                return maintainerEmail_!
            }
        }
        set {
            if newValue == "" {
                maintainerEmail_ = nil
            } else {
                maintainerEmail_ = newValue
            }
        }
    }

	public var town: String { // may be one word ("Rotterdam") or multiple words ("Den Bosch").
		get { return town_ ?? "DefaultPhotoClubTown" }  // nil shouldn't occur, but it does?
		set { town_ = newValue }
	}

    public var level2URL: URL? {
        get {
            // Checked before the default URL is built, so no URL is ever made from a museum's nickname (Data#102).
            guard !self.organizationType.isMuseum else { return nil } // no level2URL for a museum
            guard self.organizationType.isClub else { // warn if bad or new OrganizationType
                ifDebugFatalError("Unexpected organizationType: \(self.organizationType.organizationTypeName)")
                return nil // for production code
            }

            // use a default unless level2URL points to the club's own website
            let defaultURL: URL? = URL(string: "https://www.vdhamer.com/\(self.nickName)/index.html")
            guard let defaultURL else {
                ifDebugFatalError("Bad default Level 2 URL for nickname \(self.nickName)")
                return nil
            }

            guard self.level2URL_ != nil else { return defaultURL } // nobody provided a URL
            guard let website: String = self.organizationWebsite?.absoluteString else { return defaultURL }
            guard self.level2URL_!.absoluteString.lowercased().contains(website.lowercased()) else { return defaultURL }

            return level2URL_ // initial files don't reach this point when Website is (still) a dummy value
        }
        set { level2URL_ = newValue }
    }

    public var level2URLDir: URL? {
        let url: URL? = level2URL
        guard url != nil else { return nil }
        return url!.deletingLastPathComponent()
    }

    public var coordinates: CLLocationCoordinate2D {
        get { return CLLocationCoordinate2D(latitude: latitude_, longitude: longitude_) }
        set {
            latitude_ = newValue.latitude
            longitude_ = newValue.longitude
        }
    }

    var localizedRemarks: Set<LocalizedRemark> {
        (localizedRemarks_ as? Set<LocalizedRemark>) ?? []
    }

    public var localizedAddresses: Set<LocalizedAddress> {
        (localizedAddresses_ as? Set<LocalizedAddress>) ?? []
    }

    // Sorted because a relationship is a set. Within one level, array order in the JSON is the only order (Data#91).
    public var logEntries: [LogEntry] {
        ((logEntries_ as? Set<LogEntry>) ?? []).sorted {
            ($0.originalDataSourceLevel, $0.position) < ($1.originalDataSourceLevel, $1.position)
        }
    }

    // Matches the organizations that are current, meaning not former (Data#91).
    // Apps combine it with their own filters, so that the Maps tab hides former clubs and museums (#891).
    // A computed var rather than a constant, because NSPredicate isn't Sendable.
    public static var currentPredicate: NSPredicate {
        NSPredicate(format: "isFormerOrganization == NO")
    }

    // Stored as one string with a URL per line. The encoding is internal, so it can change without apps noticing.
    // Separated by newlines because a newline can't occur in a valid URL, whereas a ";" can.
    public var badWebsites: [URL] {
        (badWebsites_ ?? "").split(separator: "\n").compactMap { URL(string: String($0)) }
    }

    public func localizedAddress(for language: Language) -> LocalizedAddress? {
        localizedAddresses.first { $0.language_ == language } // is that language available? else nil.
    }

    /// Whether Apple's geocoder should be asked for this organization's town and country in `language`:
    /// true when there is no `LocalizedAddress` row for that language yet, or when the stored row was
    /// derived from coordinates that have since changed.
    ///
    /// This is the single rule for that decision. `OrganizationGeocoder` builds its work list with it and
    /// `LocalizedAddress.geocodingCounts(context:)` counts with it, so the two cannot disagree.
    /// A current row holding a placeholder ("Town?" or "Country?") does not qualify: Apple has already
    /// answered for these coordinates.
    public func needsLocalizedAddress(for language: Language) -> Bool {
        guard let address = localizedAddress(for: language) else { return true } // never geocoded in this language
        return address.prevCoordinates != coordinates // the organization moved since its localizeAddress was fetched
    }

    /// The town in `language`, falling back to the unlocalized name the JSON supplied.
    ///
    /// A missing `LocalizedAddress` row means the pair has not been reverse-geocoded in that language,
    /// which for a town is worth nothing extra to say: `town` is a real name ("Waalre"), just not
    /// translated. Callers get one string and never unwrap.
    public func localizedTown(for language: Language) -> String {
        localizedAddress(for: language)?.localizedTown ?? town
    }

    /// The country in `language`, falling back to `LocalizedAddress.unknownCountry`.
    ///
    /// Unlike the town there is no unlocalized country stored on `Organization`, so a missing row
    /// leaves nothing truthful to show and the placeholder stands in.
    public func localizedCountry(for language: Language) -> String {
        localizedAddress(for: language)?.localizedCountry ?? LocalizedAddress.unknownCountry
    }

    // Priority system to choose an item's remark in the appropriate language.
    // The choice depends on the current language settings of the device, and on available translations.
    public var localizedRemark: String {
        // don't use Locale.current.language.languageCode because this only returns languages supported by the app
        // first choice: accomodate user's language preferences according to Apple's Locale API
        for lang in Locale.preferredLanguages {
            let langID = lang.split(separator: "-").first?.lowercased() ?? "en"
            // now check if one of the user's preferences is available for this Remark
            for localRemark in localizedRemarks where localRemark.language.isoCode == langID {
                if localRemark.localizedString != nil {
                    return localRemark.localizedString!
                }
            }
        }

        // second choice: most people speak English, at least let's pretend that is the case ;-)
        for localizedRemark in localizedRemarks where localizedRemark.language.isoCode == "en" {
            if localizedRemark.localizedString != nil {
                return localizedRemark.localizedString!
            }
        }

        // third choice: use any translation available for this expertise
        if localizedRemarks.first != nil, localizedRemarks.first!.localizedString != nil {
            return "\(localizedRemarks.first!.localizedString!) [\(localizedRemarks.first!.language.isoCode)]"
        }

        // otherwise display an error message instead of a real remark
        // One string per organization type, so that translators also get to translate "club" or "museum".
        // The explicit bundle is needed because the PhotoClubHubData table lives in this package, not in the app.
        if organizationType.isClub {
            return String(localized: "No remark currently available for club \(fullName).",
                          table: "PhotoClubHubData",
                          bundle: Bundle.photoClubHubDataModule,
                          comment: "Shown below map if a club has no usable remark in its Level 1 or Level 2 file.")
        }
        if organizationType.isMuseum {
            return String(localized: "No remark currently available for museum \(fullName).",
                          table: "PhotoClubHubData",
                          bundle: Bundle.photoClubHubDataModule,
                          comment: "Shown below map if a museum has no usable remark in its Level 1 file.")
        }
        return String(localized: "No remark currently available for organization \(fullName).",
                      table: "PhotoClubHubData",
                      bundle: Bundle.photoClubHubDataModule,
                      comment: "Shown below map if an organization of unknown type has no usable remark.")
    }

}
