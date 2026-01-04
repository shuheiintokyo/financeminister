import Foundation
import CryptoKit

class PKCEManager {
    
    // MARK: - Generate Random String for Code Verifier
    /// Generates a cryptographically random code verifier (43-128 characters)
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        
        guard status == errSecSuccess else {
            fatalError("Failed to generate random bytes")
        }
        
        // Base64 URL encode without padding
        let codeVerifier = Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return codeVerifier
    }
    
    // MARK: - Generate Code Challenge (SHA256 hash of verifier)
    /// Generates code challenge by hashing the code verifier with SHA256
    static func generateCodeChallenge(from codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else {
            fatalError("Could not encode code verifier")
        }
        
        // SHA256 hash
        let digest = SHA256.hash(data: data)
        
        // Base64 URL encode without padding
        let codeChallenge = Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return codeChallenge
    }
    
    // MARK: - Generate Both at Once
    /// Generates both code verifier and code challenge
    /// Returns: (verifier: String, challenge: String)
    static func generatePKCEPair() -> (verifier: String, challenge: String) {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        return (verifier, challenge)
    }
}
