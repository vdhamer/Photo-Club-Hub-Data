//
//  OrganizationGeocoder.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 18/06/2026.
//

import CoreData             // for NSManagedObjectID
import CoreLocation         // for CLLocationCoordinate2D
import MapKit               // for MKReverseGeocodingRequest

/// Reverse-geocodes `Organization` coordinates into localized town/country strings and caches the
/// results as `LocalizedAddress` rows in CoreData.
///
/// Lives in the `Photo Club Hub Data` package so both the macOS site generator and the iOS app can
/// share the caching behaviour: a pair is only sent to Apple's geocoder when its coordinates have
/// changed since the previous run, and results survive across app launches.
///
/// Currently requires macOS 26 / iOS 26 because it relies on `MKReverseGeocodingRequest`;
/// callers on older deployment targets must add a fallback as the entire type is wrapped in `if #available`.
@available(macOS 26.0, iOS 26.0, *)
public struct OrganizationGeocoder: Sendable {

    private let maxAttempts: Int
    private let cooldownSeconds: Int // server allows 50 requests (bacame 25??) every 60 seconds

    /// - Parameters:
    ///   - maxAttempts: how often a single (organization × language) pair is retried before being dropped.
    ///   - cooldownSeconds: pause after a failed call, sized to the geocoding server's rate-limit window.
    public init(maxAttempts: Int = 3, cooldownSeconds: Int = 60) {
        self.maxAttempts = maxAttempts
        self.cooldownSeconds = cooldownSeconds
    }

    /// A Sendable snapshot of a `(Organization × Language)` pair that needs reverse-geocoding.
    ///
    /// Holds `NSManagedObjectID`s instead of `NSManagedObject`s so the value can cross
    /// context boundaries without violating CoreData thread-isolation rules.
    private struct GeocodeWorkItem: Sendable {
        // identification
        let organizationObjectID: NSManagedObjectID
        let languageObjectID: NSManagedObjectID
        let latitude: Double
        let longitude: Double
        let languageCode: String
        let organizationName: String // for log statements only - not written to the database
        var attemptCount: Int = 0 // number of failed attempts so far; item is dropped once it reaches maxAttempts
    }

    /// Reverse-geocodes every (organization × language) pair whose coordinates changed since the last geocoding run.
    ///
    /// Results are stored in `LocalizedAddress` rows in CoreData. On subsequent launches the rows survive
    /// (Organization, Language, and LocalizedAddress are not cleared on launch of this or the iOS app)
    /// so geocoding is skipped for unchanged coordinates.
    ///
    /// The work list is drained until empty: a successfully geocoded (or definitively empty) item is removed,
    /// while a failed item is re-queued and retried after a 60 s cooldown.
    ///
    /// Apple's geocoder is rate-limited, so the cooldown limits wasted calls to roughly one per minute
    /// while a throttle window is open. Each item is retried at most `maxAttempts` times before being dropped,
    /// guaranteeing the loop terminates even if a coordinate fails permanently.
    public func geocodeChangedAddresses() async {
        let bgContext = PersistenceController.shared.container.newBackgroundContext()
        bgContext.name = "reverse geocoding of organizations"
        bgContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        bgContext.automaticallyMergesChangesFromParent = true

        // build list of GeocodeWordItems that need a localized Town and Country
        var queue: [GeocodeWorkItem] = buildWorkItems(bgContext: bgContext)
        if !queue.isEmpty {
            print("Reverse Geocoding \(queue.count) (organization × language) pair(s)...")
        } else {
            print("No organizations found that require reverse geocoding.")
        }

        while !queue.isEmpty {
            var item = queue.removeFirst()
            do {
                guard let addressStrings = try await reverseGeocode(item) else { continue } // no placemark: drop item

                let coords = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                let organizationObjectID = item.organizationObjectID // immutable copy so the closure
                let languageObjectID = item.languageObjectID         // doesn't capture the mutable `item`
                bgContext.performAndWait {
                    guard let org = try? bgContext.existingObject(with: organizationObjectID) as? Organization,
                          let language = try? bgContext.existingObject(with: languageObjectID) as? Language
                    else {
                        return // unreachable: both IDs were fetched from this same bgContext moments ago
                    }
                    LocalizedAddress.findCreateUpdate(bgContext: bgContext,
                                                      organization: org,
                                                      language: language,
                                                      newLocalizedAddressStrings: addressStrings,
                                                      newCoordinates: coords)
                }
                // The queue is ordered organization-major (all languages of one organization
                // are adjacent), so a change in organizationObjectID marks an organization
                // boundary. Saving there advances the "translated locations" counter one
                // organization at a time (i.e. by the number of languages in use).
                if queue.first?.organizationObjectID != item.organizationObjectID {
                    saveBatch(bgContext: bgContext)
                }
            } catch {
                item.attemptCount += 1
                print("Geocoding failed for \(item.organizationName) [\(item.languageCode)]: \(error)")
                guard item.attemptCount < self.maxAttempts else {
                    print("""
                          Dropping \(item.organizationName) [\(item.languageCode)] \
                          after \(self.maxAttempts) attempts.
                          """)
                    continue
                }
                queue.append(item) // re-queue for retry after the cooldown
                saveBatch(bgContext: bgContext)
                print("Geocoding rate-limit pause (\(self.cooldownSeconds) s)...")
                try? await Task.sleep(for: .seconds(self.cooldownSeconds))
            }
        }

        saveBatch(bgContext: bgContext)
        print("Geocoding complete.")
    }

    /// Saves any pending geocoding results to the persistent store.
    private func saveBatch(bgContext: NSManagedObjectContext) {
        bgContext.performAndWait {
            guard bgContext.hasChanges else { return }
            do {
                try bgContext.save()
            } catch {
                print("Saving of geocoding results failed: \(error)")
            }
        }
    }

    /// Fetches all (organization × language) pairs that need reverse-geocoding and returns them as work items.
    ///
    /// A pair needs geocoding when no `LocalizedAddress` exists yet, or when the stored `prevCoordinates`
    /// differs from the organization's current coordinates. Only languages that have expertise translations
    /// are fetched (currently EN and NL); the others exist in CoreData but are not used on the website.
    private func buildWorkItems(bgContext: NSManagedObjectContext) -> [GeocodeWorkItem] {
        bgContext.performAndWait {
            let orgRequest: NSFetchRequest<Organization> = Organization.fetchRequest()
            orgRequest.predicate = NSPredicate(format: "TRUEPREDICATE")
            let organizations: [Organization] = (try? bgContext.fetch(orgRequest)) ?? []

            // Only languages with Expertise translations get pages on the website.
            // Filtering here avoids a nested performAndWait inside the language loop.
            let langRequest: NSFetchRequest<Language> = Language.fetchRequest()
            langRequest.predicate = NSPredicate(format: "localizedExpertises_.@count > 0")
            let languages = (try? bgContext.fetch(langRequest)) ?? []
            if languages.isEmpty {
                ifDebugFatalError("No languages found for which reverse geoencoding is required.")
            }

            var items: [GeocodeWorkItem] = []
            for org in organizations {
                for language in languages {
                    let existing = org.localizedAddress(for: language)
                    if existing == nil || org.coordinates != existing!.prevCoordinates {
                        items.append(GeocodeWorkItem(
                            organizationObjectID: org.objectID,
                            languageObjectID: language.objectID,
                            latitude: org.coordinates.latitude,
                            longitude: org.coordinates.longitude,
                            languageCode: language.isoCode,
                            organizationName: org.fullName
                        ))
                    }
                }
            }
            return items
        }
    }

    /// Issues a single `MKReverseGeocodingRequest` for the given work item and returns the
    /// localized town and country strings, or `nil` if the geocoder found no result.
    private func reverseGeocode(_ item: GeocodeWorkItem) async throws -> LocalizedAddressStrings? {
        let location = CLLocation(latitude: item.latitude, longitude: item.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        request.preferredLocale = Locale(identifier: item.languageCode)

        return try await withCheckedThrowingContinuation { cont in
            request.getMapItems { items, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: items?.first.map { mapItem in
                    LocalizedAddressStrings(
                        localizedTown: mapItem.addressRepresentations?.cityName ?? "⏳",
                        localizedCountry: mapItem.addressRepresentations?.regionName ?? "⏳"
                    )
                })
            }
        }
    }

}
