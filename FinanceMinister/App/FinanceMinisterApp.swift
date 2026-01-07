import SwiftUI
import CoreData

@main
struct FinanceMinisterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var portfolioViewModel = PortfolioViewModel()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(portfolioViewModel)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

