//
//  DataDockApp.swift
//  DataDock
//
//  Created by DURGESH TIWARI on 12/29/25.
//

import SwiftUI
import CoreData

@main
struct DataDockApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
