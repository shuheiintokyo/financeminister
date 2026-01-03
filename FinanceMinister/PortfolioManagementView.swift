import SwiftUI

struct PortfolioManagementView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var showingAddSheet = false
    @State private var selectedMarket: MarketType = .american
    @State private var searchQuery = ""
    @StateObject private var searchViewModel = StockSearchViewModel()
    @State private var selectedStock: Stock?
    @State private var quantity: String = ""
    @State private var purchasePrice: String = ""
    @State private var purchaseDate = Date()
    @State private var account = "Account 1"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.portfolioSummary.holdings.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "chart.pie")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("ポートフォリオが空です")
                            .font(.headline)
                        
                        Text("下のボタンから株を追加してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Portfolio Summary Card
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard
                            
                            // Holdings List
                            holdingsList
                        }
                        .padding()
                    }
                }
                
                // Add Stock Button
                Button(action: { showingAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("株を追加")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("ポートフォリオ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.refreshPortfolio()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                addStockSheet
            }
        }
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("総資産額")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("¥\(formatCurrency(viewModel.portfolioSummary.totalValueInJpy))")
                .font(.system(size: 32, weight: .bold, design: .default))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("評価損益")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("¥\(formatCurrency(viewModel.portfolioSummary.totalGainLoss))")
                        .font(.system(weight: .semibold))
                        .foregroundColor(viewModel.portfolioSummary.totalGainLoss >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("騰落率")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(viewModel.portfolioSummary.totalGainLossPercentage, specifier: "%.2f")%")
                        .font(.system(weight: .semibold))
                        .foregroundColor(viewModel.portfolioSummary.totalGainLossPercentage >= 0 ? .green : .red)
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("日本株")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("¥\(formatCurrency(viewModel.portfolioSummary.totalInJapaneseStocks))")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("米国株")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("¥\(formatCurrency(viewModel.portfolioSummary.totalInAmericanStocks))")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Holdings List
    private var holdingsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("保有銘柄")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(viewModel.portfolioSummary.holdings.sorted { h1, h2 in
                    let v1 = h1.stock.market == .american ? h1.currentValue * viewModel.currentExchangeRate : h1.currentValue
                    let v2 = h2.stock.market == .american ? h2.currentValue * viewModel.currentExchangeRate : h2.currentValue
                    return v1 > v2
                }) { holding in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(holding.stock.name)
                                    .font(.headline)
                                Text(holding.stock.symbol)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                let valueInJpy = holding.stock.market == .american ? holding.currentValue * viewModel.currentExchangeRate : holding.currentValue
                                Text("¥\(formatCurrency(valueInJpy))")
                                    .font(.headline)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: holding.gainLoss >= 0 ? "arrow.up.right" : "arrow.down.left")
                                    Text("\(holding.gainLossPercentage, specifier: "%.2f")%")
                                }
                                .font(.caption)
                                .foregroundColor(holding.gainLoss >= 0 ? .green : .red)
                            }
                        }
                        
                        HStack {
                            Text("数量: \(holding.quantity, specifier: "%.4g")")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            let gainLossInJpy = holding.stock.market == .american ? holding.gainLoss * viewModel.currentExchangeRate : holding.gainLoss
                            Text("評価損益: ¥\(formatCurrency(gainLossInJpy))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Button(action: {
                                viewModel.removeHolding(holding)
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("削除")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            Text(holding.account)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    if holding.id != viewModel.portfolioSummary.holdings.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Add Stock Sheet
    private var addStockSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Market Selection
                Picker("市場を選択", selection: $selectedMarket) {
                    Text("日本株").tag(MarketType.japanese)
                    Text("米国株").tag(MarketType.american)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Stock Search
                VStack(alignment: .leading, spacing: 8) {
                    Text("株を検索")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("シンボルまたは企業名", text: $searchQuery)
                            .onChange(of: searchQuery) { newValue in
                                searchViewModel.searchStocks(query: newValue, market: selectedMarket)
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Search Results Dropdown
                    if !searchViewModel.searchResults.isEmpty && !searchQuery.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(searchViewModel.searchResults) { stock in
                                Button(action: {
                                    selectedStock = stock
                                    searchQuery = ""
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stock.name)
                                            .font(.body)
                                            .foregroundColor(.black)
                                        
                                        Text("\(stock.symbol) - \(formatCurrency(stock.currentPrice)) \(stock.currency)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                if stock.id != searchViewModel.searchResults.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                
                // Selected Stock Display
                if let stock = selectedStock {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stock.name)
                                    .font(.headline)
                                Text(stock.symbol)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: { selectedStock = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text("現在価格: \(formatCurrency(stock.currentPrice)) \(stock.currency)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                    
                    // Input Fields
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Quantity
                            VStack(alignment: .leading) {
                                Text("数量")
                                    .font(.headline)
                                TextField("例: 10", text: $quantity)
                                    .keyboardType(.decimalPad)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                            
                            // Purchase Price
                            VStack(alignment: .leading) {
                                Text("購入単価 (\(stock.currency))")
                                    .font(.headline)
                                TextField("例: 150.00", text: $purchasePrice)
                                    .keyboardType(.decimalPad)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                            
                            // Purchase Date
                            VStack(alignment: .leading) {
                                Text("購入日")
                                    .font(.headline)
                                DatePicker(
                                    "",
                                    selection: $purchaseDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                            }
                            
                            // Account
                            VStack(alignment: .leading) {
                                Text("口座")
                                    .font(.headline)
                                TextField("例: SBI証券", text: $account)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            resetForm()
                            showingAddSheet = false
                        }) {
                            Text("キャンセル")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addHolding) {
                            Text("追加")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(!canAddHolding())
                    }
                    .padding()
                } else {
                    Spacer()
                }
            }
            .navigationTitle("株を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        resetForm()
                        showingAddSheet = false
                    }
                }
            }
            .alert("確認", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Helpers
    private func canAddHolding() -> Bool {
        guard let _ = selectedStock,
              !quantity.isEmpty,
              Double(quantity) ?? 0 > 0,
              !purchasePrice.isEmpty,
              Double(purchasePrice) ?? 0 > 0 else {
            return false
        }
        return true
    }
    
    private func addHolding() {
        guard let stock = selectedStock,
              let qty = Double(quantity),
              let price = Double(purchasePrice),
              qty > 0,
              price > 0 else {
            alertMessage = "正しい値を入力してください"
            showAlert = true
            return
        }
        
        let holding = PortfolioHolding(
            stock: stock,
            quantity: qty,
            purchasePrice: price,
            purchaseDate: purchaseDate,
            account: account.isEmpty ? "Default" : account
        )
        
        viewModel.addHolding(holding)
        
        alertMessage = "\(stock.name)を追加しました"
        showAlert = true
        resetForm()
        showingAddSheet = false
    }
    
    private func resetForm() {
        selectedStock = nil
        quantity = ""
        purchasePrice = ""
        purchaseDate = Date()
        account = "Account 1"
        searchQuery = ""
    }
}

#Preview {
    PortfolioManagementView()
        .environmentObject(PortfolioViewModel())
}
