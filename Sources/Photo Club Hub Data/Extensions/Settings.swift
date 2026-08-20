//
//  Settings.swift
//  Photo Club Hub
//
//  Created by Peter van den Hamer on 23/06/2024.
//

import Foundation

public struct Settings {

    @available(*, unavailable)
    init() {
        fatalError("init() is not available. Settings only holds a few static computer properties.")
    }

    static let userDefaultsKey: String = "dataResetPending292b4657" // must match id of Settings toggle in Root.plist
    private static let prevUserDefaultsKeys: Set<String> = ["dataResetPending291b4656",
                                                            "dataResetPending290b4655",
                                                            "dataResetPending288b4654",
                                                            "dataResetPending286b4652",
                                                            "dataResetPending285b4651",
                                                            "dataResetPending284b4650",
                                                            "dataResetPending283b4649",
                                                            "dataResetPending282b4647",
                                                            "dataResetPending282b4646",
                                                            "dataResetPending280b4644",
                                                            "dataResetPending280",
                                                            "dataResetPending272",
                                                            "dataResetPending"]

    // Doesn't really work in Photo Club Hub HTML until the version numbers are synchronized
    public static var dataResetPending: Bool { // stored as a string shown in Settings
        // returns true only when read for the first time

        if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
            UserDefaults.standard.set(true, forKey: userDefaultsKey) // if key missing, set value to true
        }

        let prevValue = UserDefaults.standard.bool(forKey: userDefaultsKey) // return whether reset needed

        if prevValue {
            UserDefaults.standard.set(false, forKey: userDefaultsKey) // return true only once
            for key in prevUserDefaultsKeys { // also remove all previously used dataResetPending keys from UserDefaults
                UserDefaults.standard.removeObject(forKey: key) // not important, just a cleanup
            }
        }

        return prevValue // if true, app will immediately do a data reset
    } // implicit getter only

    public static var manualDataLoading: Bool { // controlled by toggle in Settings
        // Setting this to true clears the existing database and skips loading any data on app startup.
        // It displays "Manual loading" in the Prelude startup screen as a warning that the mode is set.
        // The missing club/museum/member data can be loaded manually by swiping down on e.g., the Portfolio screen.
        UserDefaults.standard.bool(forKey: "manualDataLoading") // here we are happy with missing key → false
    }

    static var extraCoreDataSaves: Bool { // controlled by toggle in Settings
        // Important setting that should normally be kept false.
        // It adds extra ManagedObjectContext.save() transactions to the minimal set of save's.
        // It is needed for testing purposes only.
        UserDefaults.standard.bool(forKey: "extraCoreDataSaves") // here we are happy with missing key → false
    }

    // `showTemplateClubs` used to live here. It read a "showTemplateClubs" key that no Root.plist ever
    // offered and that nothing ever wrote, so it was permanently false, and it had no call site in this
    // package or in either consumer. Template clubs are in fact always loaded; whether they are *shown*
    // is decided in the app by SettingsViewModel.showTemplateClubs, which filters on the club nickname.
    // Removed in #19.

    public static var errorOnCoreDataMerge: Bool { // controlled by toggle in Settings
        // Instructs the app to set CoreData NSManagedObjectContext.mergePolicy to NSMergePolicy.error
        // This causes the app to stop when a uniqueness constraint violation or a merging issue in encountered.
        // Setting this Bool to true only does something if the app is in Debug mode. So does nothing for end users.
        UserDefaults.standard.bool(forKey: "errorOnCoreDataMerge") // if the key is missing, this returns false
    }

}
