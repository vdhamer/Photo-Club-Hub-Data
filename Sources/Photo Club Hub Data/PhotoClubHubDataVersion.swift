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
/// Update this in the same commit that tags a release, before pushing the tag.
public enum PhotoClubHubDataVersion {

    /// The version this package ships under, e.g. `"3.0.0"`. Must equal its git tag.
    public static let semver = "3.0.3"
}
