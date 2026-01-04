import Foundation
import Combine
import UIKit

class YahooOAuth2Manager: NSObject, ObservableObject {
    
    // MARK: - Properties
    @Published var accessToken: String?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    static let shared = YahooOAuth2Manager()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - OAuth Configuration
    // Your actual Yahoo Finance OAuth credentials
    private let clientID = "dj0yJmk9RUxBZzFSVVhUTFFRJmQ9WVdrOVVXSnpOVTlyU3pZbWNHbzlNQT09JnM9Y29uc3VtZXJzZWNyZXQmc3Y9MCZ4PTAy"
    private let redirectURI = "financeministerapp://oauth-callback"
    private let tokenEndpoint = "https://api.login.yahoo.com/oauth2/get_token"
    private let authorizationEndpoint = "https://api.login.yahoo.com/oauth2/request_auth"
    
    // MARK: - Storage Keys
    private let codeVerifierKey = "yahoo_oauth_code_verifier"
    private let accessTokenKey = "yahoo_oauth_access_token"
    private let refreshTokenKey = "yahoo_oauth_refresh_token"
    private let tokenExpirationKey = "yahoo_oauth_expiration"
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    // MARK: - Check if Already Authenticated
    func checkAuthenticationStatus() {
        if let savedToken = UserDefaults.standard.string(forKey: accessTokenKey),
           let expiration = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date,
           expiration > Date() {
            self.accessToken = savedToken
            self.isAuthenticated = true
            print("DEBUG: Restored existing access token")
        } else {
            self.isAuthenticated = false
            print("DEBUG: No valid saved token, need to authenticate")
        }
    }
    
    // MARK: - Start OAuth Flow
    func startOAuthFlow() {
        // Step 1: Generate PKCE pair
        let (codeVerifier, codeChallenge) = PKCEManager.generatePKCEPair()
        
        // Step 2: Save code verifier (needed later to exchange for token)
        UserDefaults.standard.set(codeVerifier, forKey: codeVerifierKey)
        print("DEBUG: Generated PKCE pair")
        print("  Code Verifier: \(codeVerifier.prefix(20))...")
        print("  Code Challenge: \(codeChallenge.prefix(20))...")
        
        // Step 3: Build authorization URL
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),  // S256 = SHA256
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "state", value: generateState()),  // CSRF protection
        ]
        
        guard let url = components.url else {
            errorMessage = "Failed to build authorization URL"
            print("DEBUG: Error building URL")
            return
        }
        
        print("DEBUG: Opening Yahoo login")
        print("DEBUG: Authorization URL: \(url.absoluteString)")
        
        // Step 4: Open in browser (user logs in)
        DispatchQueue.main.async {
            print("DEBUG: Attempting to open Safari on main thread")
            if UIApplication.shared.canOpenURL(url) {
                print("DEBUG: URL can be opened, calling UIApplication.shared.open")
                UIApplication.shared.open(url) { success in
                    if success {
                        print("DEBUG: Successfully opened Safari")
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to open Yahoo login"
                            print("DEBUG: Failed to open URL in Safari")
                        }
                    }
                }
            } else {
                print("DEBUG: ERROR - URL cannot be opened by any app!")
                DispatchQueue.main.async {
                    self.errorMessage = "Cannot open Yahoo login. Check Safari is installed."
                }
            }
        }
    }
    
    // MARK: - Handle OAuth Callback
    func handleOAuthCallback(url: URL) {
        print("DEBUG: Received callback: \(url.absoluteString)")
        
        // Step 1: Extract authorization code from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            errorMessage = "Invalid callback URL"
            print("DEBUG: Could not parse callback URL")
            return
        }
        
        // Look for error in response
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            errorMessage = "OAuth error: \(error)"
            print("DEBUG: OAuth error: \(error)")
            return
        }
        
        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            errorMessage = "No authorization code in callback"
            print("DEBUG: No authorization code")
            return
        }
        
        print("DEBUG: Got authorization code: \(code.prefix(20))...")
        
        // Step 2: Exchange code for access token
        exchangeCodeForToken(code: code)
    }
    
    // MARK: - Exchange Authorization Code for Token
    private func exchangeCodeForToken(code: String) {
        // Get the code verifier we saved earlier
        guard let codeVerifier = UserDefaults.standard.string(forKey: codeVerifierKey) else {
            errorMessage = "Code verifier not found"
            print("DEBUG: Code verifier not saved!")
            return
        }
        
        print("DEBUG: Exchanging code for token...")
        
        // Build request
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": codeVerifier,  // This proves it's the same app!
        ]
        
        // Encode parameters
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)
        
        print("DEBUG: Sending token request...")
        
        // Send request
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("DEBUG: Token request failed with status \(status)")
                    // Print response body for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("DEBUG: Response: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to get token: \(error.localizedDescription)"
                            print("DEBUG: Token exchange failed: \(error)")
                        }
                    case .finished:
                        break
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.handleTokenResponse(response)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Handle Token Response
    private func handleTokenResponse(_ response: TokenResponse) {
        DispatchQueue.main.async {
            // Save access token
            self.accessToken = response.accessToken
            self.isAuthenticated = true
            
            // Save to UserDefaults
            UserDefaults.standard.set(response.accessToken, forKey: self.accessTokenKey)
            
            // Save refresh token if provided
            if let refreshToken = response.refreshToken {
                UserDefaults.standard.set(refreshToken, forKey: self.refreshTokenKey)
            }
            
            // Save expiration time
            let expirationTime = Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
            UserDefaults.standard.set(expirationTime, forKey: self.tokenExpirationKey)
            
            // Clean up code verifier (no longer needed)
            UserDefaults.standard.removeObject(forKey: self.codeVerifierKey)
            
            print("DEBUG: Successfully authenticated!")
            print("  Access Token: \(response.accessToken.prefix(20))...")
            print("  Expires in: \(response.expiresIn ?? 3600) seconds")
        }
    }
    
    // MARK: - Generate State (CSRF Protection)
    private func generateState() -> String {
        var buffer = [UInt8](repeating: 0, count: 16)
        SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
    }
    
    // MARK: - Logout
    func logout() {
        accessToken = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
        UserDefaults.standard.removeObject(forKey: codeVerifierKey)
        print("DEBUG: Logged out")
    }
    
    // MARK: - Check Token Expiration
    func isTokenExpired() -> Bool {
        guard let expiration = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date else {
            return true
        }
        return expiration <= Date()
    }
}

// MARK: - Token Response Model
struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
