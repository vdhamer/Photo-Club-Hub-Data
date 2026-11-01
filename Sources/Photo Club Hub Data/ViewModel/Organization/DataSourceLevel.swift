//
//  DataSourceLevel.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 01/11/2026.
//

/// The level of the JSON file that a record was first found in.
///
/// The raw value is what `LogEntry.originalDataSourceLevel` stores (an `Int16` in CoreData), so don't renumber cases.
/// Only Level 1 files can hold a logbook today; Level 2 is expected to follow (Data#92).
/// Rows of different levels share one relationship, so a loader must only match, update or delete the rows of its own
/// level. Otherwise the `position` of a Level 1 entry and that of a Level 2 entry would be mixed up.
public enum DataSourceLevel: Int16, Sendable, CaseIterable {
    case level0 = 0
    case level1 = 1
    case level2 = 2
    case level3 = 3
}
