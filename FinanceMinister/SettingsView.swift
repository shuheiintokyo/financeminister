import SwiftUI

struct SettingsView: View {
    @State private var showingInstructions = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // Information Section
                Section(header: Text("情報")) {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("このアプリについて")
                        }
                    }
                    
                    NavigationLink(destination: InstructionsView()) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.blue)
                            Text("使い方")
                        }
                    }
                }
                
                // Data Management Section
                Section(header: Text("データ管理")) {
                    NavigationLink(destination: DataManagementView()) {
                        HStack {
                            Image(systemName: "externaldrive.badge.xmark")
                                .foregroundColor(.red)
                            Text("データをリセット")
                        }
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("アプリ名")
                    Spacer()
                    Text("ポートフォリオトラッカー")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("開発者")
                    Spacer()
                    Text("Your Name")
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("説明")) {
                Text("このアプリは、日本株と米国株の両方を追跡して、統一されたポートフォリオビューでリアルタイムの評価額、損益、為替レートの影響を確認できます。")
                    .font(.body)
            }
            
            Section(header: Text("主な機能")) {
                VStack(alignment: .leading, spacing: 8) {
                    FeatureItem(icon: "chart.pie.fill", title: "ポートフォリオ管理", description: "日本株と米国株を一元管理")
                    FeatureItem(icon: "magnifyingglass", title: "株検索", description: "シンボルまたは企業名で株を検索")
                    FeatureItem(icon: "chart.line.uptrend.xyaxis", title: "パフォーマンス分析", description: "複数の期間での価格推移を表示")
                    FeatureItem(icon: "dollarsign.circle.fill", title: "為替計算", description: "自動的に米国株を円に換算")
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("このアプリについて")
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Instructions View
struct InstructionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                InstructionSection(
                    title: "1. 株を追加する",
                    steps: [
                        "ポートフォリオタブで「株を追加」ボタンをタップします",
                        "日本株または米国株を選択します",
                        "検索ボックスで株を検索します（シンボルまたは企業名）",
                        "検索結果から株を選択します",
                        "数量、購入単価、購入日、口座を入力します",
                        "「追加」ボタンをタップして確定します"
                    ]
                )
                
                InstructionSection(
                    title: "2. ポートフォリオを確認する",
                    steps: [
                        "ポートフォリオタブで全体の資産を確認できます",
                        "総資産額、評価損益、騰落率が表示されます",
                        "日本株と米国株の内訳も表示されます",
                        "各銘柄の詳細情報は一覧で表示されます",
                        "「更新」ボタンで最新の為替レートを取得します"
                    ]
                )
                
                InstructionSection(
                    title: "3. パフォーマンスを分析する",
                    steps: [
                        "パフォーマンスタブで過去の価格推移を確認できます",
                        "期間を選択して（1週間、1ヶ月、3ヶ月、1年、5年）表示期間を変更します",
                        "為替レートの推移を確認できます",
                        "個別銘柄の価格推移を表示できます",
                        "統計情報で詳細な数値を確認できます"
                    ]
                )
                
                InstructionSection(
                    title: "4. 銘柄を削除する",
                    steps: [
                        "ポートフォリオタブで削除したい銘柄を見つけます",
                        "「削除」ボタンをタップします",
                        "銘柄がポートフォリオから削除されます"
                    ]
                )
                
                InstructionSection(
                    title: "重要な注意",
                    steps: [
                        "このアプリは取引機能を持たないため、実際の取引には使用できません",
                        "価格データは定期的に更新されます",
                        "米国株の評価額は自動的に現在の為替レートで計算されます",
                        "データはiPhone内に保存されます"
                    ]
                )
            }
            .padding()
        }
        .navigationTitle("使い方")
    }
}

struct InstructionSection: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .cornerRadius(12)
                        
                        Text(step)
                            .font(.body)
                            .lineLimit(nil)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Data Management View
struct DataManagementView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var showConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("すべてのデータを削除")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ポートフォリオのすべての銘柄データを削除します。この操作は取り消せません。")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Button(action: { showConfirmation = true }) {
                        Text("すべてのデータをリセット")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 12)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("データ管理")
        .confirmationDialog(
            "確認",
            isPresented: $showConfirmation,
            actions: {
                Button("削除", role: .destructive) {
                    viewModel.clearAllHoldings()
                }
                Button("キャンセル", role: .cancel) {}
            },
            message: {
                Text("本当にすべてのデータを削除してもよろしいですか？この操作は取り消せません。")
            }
        )
    }
}

#Preview {
    SettingsView()
}
