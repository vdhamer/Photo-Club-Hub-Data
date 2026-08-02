//
//  PhotoClubHubDataVersion.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 30/07/2026.
//

/// The package's own version, available at runtime.
///
/// SwiftPM code cannot read the git tag it was resolved from, and `Bundle.module` carries no version,
/// so the number has to be duplicated here. Two checks depend on that duplication:
/// - the release checklist asserts this constant equals the tag being pushed;
/// - a consuming app can assert its own `major.minor` equals the package's, since the three
///   repositories share a synchronized `major.minor` release train (see README).
///
/// Update this in the same commit as any train bump, before tagging.
public enum PhotoClubHubDataVersion {
    public static let semver = "2.11.2"
}
