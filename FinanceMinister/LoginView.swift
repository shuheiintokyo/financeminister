import SwiftUI

struct LoginView: View {
    @StateObject var oauthManager = YahooOAuth2Manager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if oauthManager.isAuthenticated {
                // MARK: - Authenticated Content
                VStack(spacing: 15) {
                    // Header
                    VStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("ログイン済み")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 20)
                    
                    // Divider
                    Divider()
                    
                    // Token Info
                    VStack(alignment: .leading, spacing: 10) {
                        Text("認証トークン")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(oauthManager.accessToken?.prefix(30).description ?? "トークンなし")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Token Status
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("トークン有効期限:")
                            Spacer()
                            if oauthManager.isTokenExpired() {
                                Text("期限切れ")
                                    .foregroundColor(.red)
                            } else {
                                Text("有効")
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Logout Button
                    Button(action: {
                        oauthManager.logout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("ログアウト")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                
            } else {
                // MARK: - Login Content
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Yahoo Finance へのログイン")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("リアルタイム株価データにアクセスするには Yahoo でログインしてください")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Error Message
                    if let error = oauthManager.errorMessage {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamation.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Login Button
                    Button(action: {
                        oauthManager.startOAuthFlow()
                    }) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Yahoo でログイン")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label("リアルタイム株価", systemImage: "chart.line")
                            Text("Yahoo Finance の最新データを取得します")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Label("安全な認証", systemImage: "lock.shield")
                            Text("PKCE を使用した安全な OAuth 2.0 認証")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Label("ローカル保存", systemImage: "iphone")
                            Text("トークンはデバイスにのみ保存されます")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .padding()
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            oauthManager.checkAuthenticationStatus()
        }
    }
}

#Preview {
    LoginView()
}
