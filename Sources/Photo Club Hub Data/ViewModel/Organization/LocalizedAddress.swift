//
//  LocalizedAddress.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 18/06/2026.
//

import CoreData // for NSFetchRequest and NSManagedObjectContext
import CoreLocation // for CLLocationCoordinate2D

extension LocalizedAddress { // expose computed properties (some related to handling optionals)

    @available(*, unavailable) // blocks use of initialization: LocalizedAddress()
    convenience init() {
        fatalError("init() is not available. Use .findCreateUpdate instead.")
    }

    // MARK: - getters (setting is done via findCreateUpdate function)

    var organization: Organization { // getter to non-optional organization
        if let organization = organization_ {
            return organization
        } else {
            fatalError("Error because organization is nil") // something is fundamentally wrong if this happens
        }
    }

    var language: Language { // getter to non-optional language
        if let language = language_ {
            return language
        } else {
            fatalError("Error because language is nil") // something is fundamentally wrong if this happens
        }
    }

    public var prevCoordinates: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: prevLatitude, longitude: prevLongitude) }
        set {
            prevLatitude = newValue.latitude
            prevLongitude = newValue.longitude
        }
    }

    var localizedTown: String { localizedTown_ ?? "" }
    var localizedCountry: String { localizedCountry_ ?? "" }

    // MARK: - find (if it exists) or create (if it doesn't exist) a LocalizedAddress

    /// Finds the existing `LocalizedAddress` for the given (organization × language) pair or creates a new pair,
    /// then `update`s its town, country, and `prevCoordinates` from the provided values.
    /// Returns `true` if any stored value changed.
    @discardableResult
    public static func findCreateUpdate(bgContext: NSManagedObjectContext,
                                        organization: Organization, // part of unique identifier
                                        language: Language, // part of unique identifier
                                        newLocalizedAddressStrings: LocalizedAddressStrings,
                                        newCoordinates: CLLocationCoordinate2D
                                ) -> Bool { // true if something got updated (or created?)

        let predicateFormat: String = "organization_ = %@ AND language_ = %@" // avoid localization
        let predicate = NSPredicate(format: predicateFormat,
                                    argumentArray: [organization, language])
        let fetchRequest: NSFetchRequest<LocalizedAddress> = LocalizedAddress.fetchRequest()
        fetchRequest.predicate = predicate
        let localizedAddresses: [LocalizedAddress] = (try? bgContext.fetch(fetchRequest)) ?? [] // throws → []

        if localizedAddresses.count > 1 { // a Core Data uniqueness constraint exists that should prevent this
            ifDebugFatalError("Query returned multiple (\(localizedAddresses.count)) localized addresses for " +
                              "\(organization.fullNameTown) for language \(language.isoCode)",
                              file: #fileID, line: #line)
        }

        let localizedAddress: LocalizedAddress
        if let existingLocalizedAddress = localizedAddresses.first { // handles case for .count >= 1 (normally == 1)
            localizedAddress = existingLocalizedAddress // found an object for the (organization × language) combination
        } else { // handles case for .count == 0
            let nsEntityDescription = NSEntityDescription.entity(forEntityName: "LocalizedAddress", in: bgContext)!
            localizedAddress = LocalizedAddress(entity: nsEntityDescription, insertInto: bgContext)
            localizedAddress.organization_ = organization
            localizedAddress.language_ = language
        }

        // At this point, localizedAddress has the required ID, but could have outdated coordinates or localized strings
        // Adjusting these non-ID properties is handled in update()
        let hasChanged = localizedAddress.update(newLocalizedAddressStrings: newLocalizedAddressStrings,
                                                 newCoordinates: newCoordinates)

        do {
            if bgContext.hasChanges && Settings.extraCoreDataSaves { // optimisation
                try bgContext.save()
            }
        } catch {
            ifDebugFatalError("Save failed for LocalizedAddress \(organization.fullName) [\(language.isoCode)]",
                              file: #fileID, line: #line)
        }
        return hasChanged
    }

    private func update(newLocalizedAddressStrings: LocalizedAddressStrings,
                        newCoordinates: CLLocationCoordinate2D) -> Bool {
        var changed = false
        if self.localizedTown_ != newLocalizedAddressStrings.localizedTown {
            self.localizedTown_ = newLocalizedAddressStrings.localizedTown
            changed = true
        }
        if self.localizedCountry_ != newLocalizedAddressStrings.localizedCountry {
            self.localizedCountry_ = newLocalizedAddressStrings.localizedCountry
            changed = true
        }
        if self.prevCoordinates != newCoordinates {
            self.prevCoordinates = newCoordinates
            changed = true }
        return changed
    }

    // MARK: - count utility functions

    /// Returns the total number of `LocalizedAddress` objects in the CoreData store.
    /// Intended for use in tests.
    static func count(context: NSManagedObjectContext) -> Int {
        context.performAndWait {
            let fetchRequest: NSFetchRequest<LocalizedAddress> = LocalizedAddress.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "TRUEPREDICATE")
            return (try? context.fetch(fetchRequest))?.count ?? 0
        }
    }

}

public struct LocalizedAddressStrings: Sendable { // only used to decrease parameter count in a function by one
    public let localizedTown: String // e.g. "Parijs" (NL) or "Paris" (EN)
    public let localizedCountry: String // e.g. "Frankrijk" (NL) or "France" (EN)

    public init(localizedTown: String, localizedCountry: String) { // explicit initializer because it needs to be public
        self.localizedTown = localizedTown
        self.localizedCountry = localizedCountry
    }
}
