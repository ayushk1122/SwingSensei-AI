//
//  SwingSensei_AIApp.swift
//  SwingSensei AI
//  Testing commit
//  Created by Ayush Krishnappa on 8/21/24.
//

import SwiftUI

@main
struct SwingSensei_AIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
