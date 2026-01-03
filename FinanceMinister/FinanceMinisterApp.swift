//
//  FinanceMinisterApp.swift
//  FinanceMinister
//
//  Created by Shuhei Kinugasa on 2026/01/03.
//

import SwiftUI
import CoreData

@main
struct FinanceMinisterApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
