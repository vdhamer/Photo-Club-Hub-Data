//
//  NSManagedObject+isUsable.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 03/08/2026.
//

import CoreData // for NSManagedObject

public extension NSManagedObject {

    /// Whether this object can still be read through the non-optional computed accessors.
    ///
    /// Deleting a managed object makes Core Data apply the Nullify delete rules straight away, so a
    /// deleted object keeps its attributes but loses every relationship. Pull-to-refresh deletes the
    /// whole store on the viewContext while the lists are on screen, and SwiftUI keeps rendering the
    /// outgoing rows for a frame or two — with an animated `@FetchRequest` it does so deliberately,
    /// for the duration of the removal animation. Accessors like `MemberPortfolio.photographer` or
    /// `Organization.organizationType` would hit their `fatalError` on such a row.
    ///
    /// Filtering a collection on this property keeps deleted objects out of the view tree, which
    /// leaves the accessors free to keep treating a nil relationship on a *live* object as the
    /// programming error it is (issue #802).
    var isUsable: Bool { !isDeleted && managedObjectContext != nil }

}
