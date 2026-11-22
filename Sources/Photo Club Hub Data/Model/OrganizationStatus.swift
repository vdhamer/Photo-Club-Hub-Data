//
//  OrganizationStatus.swift
//  Photo Club Hub
//
//  Created by Claude Code (guided by Peter van den Hamer) on 22/11/2026.
//

import Foundation // for Bundle

/// Status of a club/museum as used to determine whether or how to display it (Data#116).
///
/// Every Level 1 record has exactly one status. It is set by the `"status"` key of the record's log entries:
/// the last entry that has the key decides, and a record without such an entry is `active` by default.
/// - The enum's `rawValue` is the value of the `"status"` key in a Level 1 file, and the value stored in Core Data.
/// - An inactive organization is the counterpart of a former member, but at the club level.
/// - The apps determine how to show these states: `inactive` and `possiblyInactive` may have the same icon,
///   but a different textual description.
public enum OrganizationStatus: String, CaseIterable, Sendable {
    /// Not in scope, such as an art circle listed only so the club-list generator recognizes it. Never shown.
    case rejected

    /// In scope and active: shown with a normal pin and card in the iOS app's maps. This is the "normal" case.
    case active

    /// We are convinced that the organization is no longer active.
    case inactive

    /// There are clear signs that the organization may no longer be active.
    case possiblyInactive
}

/*
 Rendering in the iOS map tab:
    rejected → not shown (but recorded for data maintenance purposes)
    active → normal marker on the map
    inactive/possiblyInactive → ghost-like marker that may be visible - depending on Settings.
 The inactive vs possiblyInactive distinction can be used for variants in wording (see below).
 */

/// Localized labels for `OrganizationStatus`, in the same two variants as for `MemberStatus`.
extension OrganizationStatus {
    /// The label to show with a ghost organization, in the system locale. nil means that nothing is shown,
    /// because the organization is either shown normally (`active`) or not at all (`rejected`).
    public var displayNameForAppUI: String? { displayNameForHTML(languageBundle: .photoClubHubDataModule) }

    /// The same label as `displayNameForAppUI`, in the language of the supplied bundle.
    /// - Parameter languageBundle: typically from `Bundle.photoClubHubDataModuleForLanguage(_:)`.
    public func displayNameForHTML(languageBundle: Bundle) -> String? { // expect name to change soon (#117)
        switch self {
        case .rejected, .active:
            return nil
        case .inactive:
            return String(localized: "No longer active",
                          table: "PhotoClubHubData",
                          bundle: languageBundle,
                          comment: "Label of a club or museum that a source confirms is no longer active.")
        case .possiblyInactive:
            return String(localized: "May no longer be active",
                          table: "PhotoClubHubData",
                          bundle: languageBundle,
                          comment: "Label of a club or museum assumed, without confirmation, to be no longer active.")
        }
    }
}
