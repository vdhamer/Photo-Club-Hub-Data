//
//  MemberRolesAndStatusTest.swift
//  Photo Club HubTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 09/10/2026.
//

import Testing
import SwiftyJSON // for JSON struct
@testable import Photo_Club_Hub_Data

// Deceased members are a strict subset of former members.
// The JSON reader enforces this whatever the order or content of the status keys (vdhamer/Photo-Club-Hub#609).
@Suite("Tests reading member status from JSON") struct MemberRolesAndStatusTests {

    private func status(_ jsonStatus: JSON) -> MemberRolesAndStatus {
        MemberRolesAndStatus(jsonRoles: JSON([String: Any]()), jsonStatus: jsonStatus)
    }

    @Test("Deceased implies former") func deceasedImpliesFormer() {
        let memberRS = status(JSON(["isDeceased": true]))
        #expect(memberRS.status[.deceased] == true)
        #expect(memberRS.status[.former] == true)
    }

    @Test("Deceased overrules an explicit isFormerMember: false") func deceasedOverrulesNotFormer() {
        let memberRS = status(JSON(["isDeceased": true, "isFormerMember": false]))
        #expect(memberRS.status[.deceased] == true)
        #expect(memberRS.status[.former] == true)
    }

    @Test("Not deceased leaves isFormerMember as given") func notDeceasedLeavesFormer() {
        #expect(status(JSON(["isDeceased": false, "isFormerMember": false])).status[.former] == false)
        #expect(status(JSON(["isDeceased": false, "isFormerMember": true])).status[.former] == true)
    }

    @Test("Absent keys stay absent, meaning no change") func absentKeysStayAbsent() {
        let memberRS = status(JSON([String: Any]()))
        #expect(memberRS.status[.deceased] == nil)
        #expect(memberRS.status[.former] == nil)
    }

}
