import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .portfolio
    
    enum Tab {
        case portfolio
        case performance
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Portfolio & Register Combined Tab
            PortfolioManagementView()
                .tabItem {
                    Label("ポートフォリオ", systemImage: "chart.pie.fill")
                }
                .tag(Tab.portfolio)
            
            // Performance Tab
            PerformanceView()
                .tabItem {
                    Label("パフォーマンス", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.performance)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .accentColor(.blue)
    }
}



// MARK: - Helper Function
func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

#Preview {
    ContentView()
        .environmentObject(PortfolioViewModel())
}
