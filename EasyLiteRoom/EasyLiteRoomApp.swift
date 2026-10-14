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
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Check for Updates...") {}
            }
        }
    }
}
