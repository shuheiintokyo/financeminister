import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var showAPIKeyInfo = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("API設定")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Alpha Vantage を使用しています")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Connected Badge
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.green)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("接続済み")
                                                .font(.headline)
                                                .foregroundColor(.green)
                                            Text("Alpha Vantage API")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Text("ログイン不要。APIキーで自動認証されます。")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        // API Status Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("APIステータス")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                StatusRow(label: "データプロバイダー", value: "Alpha Vantage")
                                Divider()
                                StatusRow(label: "認証方式", value: "APIキー (OAuth不要)")
                                Divider()
                                StatusRow(label: "無料制限", value: "25リクエスト/日")
                                Divider()
                                StatusRow(label: "レート制限", value: "1リクエスト/秒")
                                Divider()
                                StatusRow(label: "サポート範囲", value: "US & Japan Stocks")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Features Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("利用可能な機能")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                FeatureRow(icon: "magnifyingglass", title: "株検索", subtitle: "企業名またはシンボルで検索")
                                FeatureRow(icon: "chart.line", title: "リアルタイム価格", subtitle: "最新の株価を取得")
                                FeatureRow(icon: "dollarsign.circle", title: "為替レート", subtitle: "USD/JPY自動変換")
                                FeatureRow(icon: "globe", title: "グローバル対応", subtitle: "日本株＆米国株をサポート")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // No Auth Needed
                        VStack(alignment: .leading, spacing: 12) {
                            Text("セキュリティ")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("ログイン不要")
                                        .font(.subheadline)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("トークン管理不要")
                                        .font(.subheadline)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("データはローカル保存")
                                        .font(.subheadline)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("プライバシー重視")
                                        .font(.subheadline)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Ready to Use
                        VStack(alignment: .leading, spacing: 12) {
                            Text("準備完了")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("ポートフォリオタブから株の追加を開始できます。")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("最初の検索時に自動的にAlpha Vantage APIを使用します。")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                        
                        // API Info
                        Button(action: { showAPIKeyInfo.toggle() }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                Text("API情報")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .sheet(isPresented: $showAPIKeyInfo) {
                            APIInfoSheet()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("API設定")
        }
    }
}

// MARK: - Helper Views

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.black)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - API Info Sheet

struct APIInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // About Alpha Vantage
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alpha Vantage について")
                            .font(.headline)
                        
                        Text("Alpha Vantage は、株価、為替レート、テクニカル指標などの金融データをリアルタイムで提供するAPI サービスです。")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Divider()
                    
                    // Free Tier Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("無料プラン")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            DetailItem(label: "リクエスト数", value: "25/日")
                            DetailItem(label: "レート制限", value: "1リクエスト/秒")
                            DetailItem(label: "データ遅延", value: "リアルタイム")
                            DetailItem(label: "クレジットカード", value: "不要")
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Supported Markets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("サポート対象市場")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("米国株 (NYSE, NASDAQ, AMEX)")
                                        .font(.caption)
                                    Text("AAPL, MSFT, GOOGL など")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("日本株 (Tokyo Stock Exchange)")
                                        .font(.caption)
                                    Text("6758.JPX (Sony), 7203.JPX (Toyota) など")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("通貨ペア")
                                        .font(.caption)
                                    Text("USD/JPY, EUR/USD など")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Getting Started
                    VStack(alignment: .leading, spacing: 8) {
                        Text("はじめ方")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            StepItem(number: "1", text: "ポートフォリオタブに移動")
                            StepItem(number: "2", text: "「株を追加」ボタンをタップ")
                            StepItem(number: "3", text: "企業名またはシンボルで検索")
                            StepItem(number: "4", text: "検索結果から株を選択")
                            StepItem(number: "5", text: "数量と購入価格を入力")
                            StepItem(number: "6", text: "完了！自動的にAPIが使用されます")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Pricing
                    VStack(alignment: .leading, spacing: 8) {
                        Text("有料プラン (オプション)")
                            .font(.headline)
                        
                        Text("無料プランで十分ですが、より多くのリクエストが必要な場合:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            DetailItem(label: "プレミアムプラン", value: "$5/月")
                            DetailItem(label: "リクエスト数", value: "100,000/月")
                            DetailItem(label: "レート制限", value: "60/分")
                        }
                        .padding()
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Website
                    VStack(alignment: .leading, spacing: 8) {
                        Text("公式サイト")
                            .font(.headline)
                        
                        Link(destination: URL(string: "https://www.alphavantage.co")!) {
                            HStack {
                                Image(systemName: "globe")
                                Text("www.alphavantage.co")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Alpha Vantage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct StepItem: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(12)
            
            Text(text)
                .font(.caption)
            
            Spacer()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(PortfolioViewModel())
}
