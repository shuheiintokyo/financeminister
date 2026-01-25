import SwiftUI
import CoreData

@main
struct FinanceMinisterApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                PortfolioTabView()
                    .tabItem {
                        Label("Portfolio", systemImage: "chart.pie")
                    }
            }
        }
    }
}

