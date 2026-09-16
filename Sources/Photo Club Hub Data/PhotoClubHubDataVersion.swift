//
//  PhotoClubHubDataVersion.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 30/07/2026.
//

/// The package's own version, available at runtime.
///
/// SwiftPM code cannot read the git tag it was resolved from, and `Bundle.module` carries no version,
/// so the number has to be duplicated here. The release checklist asserts that this constant equals
/// the tag being pushed: both apps display it, so a stale value misreports which library a binary
/// was built against.
///
/// This is a true semantic version — MAJOR on a breaking change, MINOR on additive public API, PATCH
/// on fixes — and it is a *contract*, not a label. Consumers pin `.upToNextMajor(from:)`, so anything
/// that would break them must move the MAJOR. The two apps' own `MARKETING_VERSION`s are labels for
/// users and float independently of this number; they are aligned at 3.0.0 once and not thereafter.
/// See vdhamer/Photo-Club-Hub#808 and #17.
///
/// Bumped at the *start* of a release cycle, to the version the coming work is expected to deserve,
/// together with the matching Core Data model container (Annex C of the iOS repo's `ReleaseProcess.md`).
/// Until that release is tagged the number is a plan, and it may be overtaken: 3.0.3 sat here for days
/// and shipped as 3.1.0. What makes it true is the tag, so the number must equal the tag at the moment
/// the tag is pushed — Annex F carries the one-line check that reads this constant out of the tagged
/// tree rather than out of the working copy, where it is always right.
public enum PhotoClubHubDataVersion {

    /// The version this package ships under, e.g. `"3.0.0"`. Must equal its git tag once that tag exists.
    public static let semver = "3.5.0"
}
