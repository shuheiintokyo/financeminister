import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .login
    
    enum Tab {
        case portfolio
        case performance
        case login
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
                    Label("パフォーマンス", systemImage: "chart.line")
                }
                .tag(Tab.performance)
            
            // Login/Auth Tab
            LoginView()
                .tabItem {
                    Label("ログイン", systemImage: "lock")
                }
                .tag(Tab.login)
            
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

#Preview {
    ContentView()
        .environmentObject(PortfolioViewModel())
}
