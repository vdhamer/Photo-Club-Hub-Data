//
//  NewerPackageRequest.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 20/11/2026.
//

/// The name of a Level 1 file whose header asks for a newer Data package than the one this build contains, and the
/// version it asks for (Data#107).
///
/// Read from `LevelLoader.newerPackageRequest`. The file name and version are given so that an app can show
/// them in a message meant for a maintainer, and so the claim can be checked: if the value in that file is itself
/// wrong, it is that file that needs correcting rather than the software that needs updating.
public struct NewerPackageRequest: Sendable, Equatable {

    /// The file that asked, without ".level1.json": for example "root_".
    /// When several files ask for the same highest version, the one whose name comes alphabetically first is given.
    public let fileName: String

    /// The `minimumDataPackageVersion` as written in that file: for example "3.11.0".
    /// The version of this build is `PhotoClubHubDataVersion.semver`.
    public let minimumVersion: String
}
