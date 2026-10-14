//
//  EasyLiteRoomApp.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import SwiftUI
import CoreData

@main
struct EasyLiteRoomApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
