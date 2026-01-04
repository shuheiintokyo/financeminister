import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🔴 DEBUG: AppDelegate didFinishLaunchingWithOptions")
        
        // Check if app was launched from URL (cold start)
        if let url = launchOptions?[.url] as? URL {
            print("🔴 DEBUG: App launched with URL from launchOptions!")
            print("   URL: \(url.absoluteString)")
            handleDeepLink(url)
        }
        
        return true
    }
    
    // Primary method: handles deep links when app is already running
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("\n" + String(repeating: "=", count: 70))
        print("🔴🔴🔴 CRITICAL: AppDelegate application(_:open:options:) CALLED!!!")
        print(String(repeating: "=", count: 70))
        print("URL: \(url.absoluteString)")
        print("Scheme: \(url.scheme ?? "NIL")")
        print("Host: \(url.host ?? "NIL")")
        print("Path: \(url.path)")
        print("Query: \(url.query ?? "NIL")")
        if let sourceApp = options[.sourceApplication] {
            print("Source App: \(sourceApp)")
        }
        print(String(repeating: "=", count: 70) + "\n")
        
        handleDeepLink(url)
        return true
    }
    
    // Helper function to handle any deep link
    private func handleDeepLink(_ url: URL) {
        print("🔴 DEBUG: handleDeepLink called")
        print("   URL: \(url.absoluteString)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")
        
        // Check if this is our OAuth callback
        let isOAuthCallback = (url.scheme == "financeministerapp" && url.host == "oauth-callback") ||
                             (url.scheme == "financeministerapp" && url.path.contains("oauth-callback"))
        
        if isOAuthCallback {
            print("🔴 ✅ OAUTH CALLBACK DETECTED!")
            print("   Full URL: \(url.absoluteString)")
            
            // Call OAuth manager on main thread
            DispatchQueue.main.async {
                print("🔴 DEBUG: Dispatching to main thread")
                print("🔴 DEBUG: Calling YahooOAuth2Manager.handleOAuthCallback")
                YahooOAuth2Manager.shared.handleOAuthCallback(url: url)
            }
        } else {
            print("🔴 DEBUG: Not an OAuth callback")
            print("   Expected: scheme=financeministerapp, host=oauth-callback or path contains oauth-callback")
            print("   Got: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil"), path=\(url.path)")
        }
    }
    
    // MARK: - UISceneSession lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🔴 DEBUG: configurationForConnecting")
        
        // Also check for URLs in scene connection options
        for urlContext in options.urlContexts {
            print("🔴 DEBUG: Found URL in scene options: \(urlContext.url.absoluteString)")
            handleDeepLink(urlContext.url)
        }
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
