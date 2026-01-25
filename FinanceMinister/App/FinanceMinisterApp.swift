import SwiftUI
import CoreData

@main
struct FinanceMinisterApp: App {
    @StateObject var viewModel = PortfolioViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Start auto-refresh when app launches
                    viewModel.startAutoRefresh(intervalSeconds: 300) // Every 5 minutes
                }
        }
    }
}
