import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contentView = ContentView()
        
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // Handle OAuth callback on cold start
        for urlContext in connectionOptions.urlContexts {
            handleURL(urlContext.url)
        }
    }
    
    // CRITICAL: This method MUST exist for deep links to work
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("🔴 DEBUG: openURLContexts called!")
        for urlContext in URLContexts {
            print("🔴 DEBUG: Received URL: \(urlContext.url.absoluteString)")
            handleURL(urlContext.url)
        }
    }
    
    // Helper function to handle URLs
    private func handleURL(_ url: URL) {
        print("🔴 DEBUG: handleURL called")
        print("   URL: \(url.absoluteString)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")
        
        // Check if this is our OAuth callback
        if url.scheme == "financeministerapp" && url.host == "oauth-callback" {
            print("🔴 DEBUG: ✅ OAUTH CALLBACK DETECTED!")
            print("   Query: \(url.query ?? "nil")")
            
            // Call the OAuth manager to handle the callback
            DispatchQueue.main.async {
                print("🔴 DEBUG: Calling YahooOAuth2Manager.handleOAuthCallback")
                YahooOAuth2Manager.shared.handleOAuthCallback(url: url)
            }
        } else {
            print("🔴 DEBUG: Not an OAuth callback")
            print("   Expected: scheme=financeministerapp, host=oauth-callback")
            print("   Got: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil")")
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
