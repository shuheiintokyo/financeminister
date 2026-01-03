import SwiftUI
import CoreData

@main
struct FinanceMinisterApp: App {
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
