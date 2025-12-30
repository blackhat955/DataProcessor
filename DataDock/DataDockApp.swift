import SwiftUI

@main
struct DataDockApp: App {
    // PersistenceController is kept if we decide to use Core Data later for metadata
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
