//
//  ContentView.swift
//  iSTOCKr
//
//  Created by Harnish Devani on 18/12/24.
//

import SwiftUI
import Combine
import SwiftUICharts

struct ContentView: View {
    var body: some View {
        TabView {
            StocksView()
                .tabItem {
                    Label("Stocks", systemImage: "chart.line.uptrend.xyaxis")
                }
            NewsView()
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }
        }
    }
}

struct NewsView: View {
    var body: some View {
        NavigationView {
            List {
                // Placeholder news items
                Text("Market surges on strong earnings reports")
                Text("Federal Reserve announces new policies")
                Text("Tech stocks rally amid optimistic forecasts")
            }
            .listRowSpacing(10)
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Market News")
        }
    }
}


// MARK: - StocksView

struct StocksView: View {
    @State private var searchQuery = ""
    @State private var stocks: [Stock] = []
    @State private var searchResults: [Stock] = []
    @State private var isLoading = false
    @State private var selectedStock: Stock?
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                
                TextField("Search for a stock", text: $searchQuery, onCommit: fetchStockData)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                }
                
                // Search Results
                List(searchResults, id: \.symbol) { stock in
                    Button(action: {
                        self.selectedStock = stock
                        // Automatically add the stock to the list
                        if !stocks.contains(where: { $0.symbol == stock.symbol }) {
                            stocks.append(stock)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stock.name)
                                    .font(.headline)
                                Text(stock.symbol)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("$\(String(format: "%.2f", stock.price))")
                                    .font(.headline)
                                Text("\(String(format: "%.2f", stock.change))%")
                                    .font(.subheadline)
                                    .foregroundColor(stock.change >= 0 ? .green : .red)
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedStock) { stock in
                StockDetailPopup(stock: stock)
            }
            .navigationTitle("Stocks")
        }
    }
    
    // Fetch stock data from Yahoo Finance API
    func fetchStockData() {
        guard !searchQuery.isEmpty else { return }
        
        isLoading = true
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/market/v2/get-quotes?region=US&symbols=\(encodedQuery)"
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.addValue("2ed59ff31emsh4b4cbd1913d46bep133fadjsn18ddb9cec961", forHTTPHeaderField: "x-rapidapi-key")
        request.addValue("apidojo-yahoo-finance-v1.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            isLoading = false
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(QuoteResponse.self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = decodedResponse.quoteResponse.result.map { quote in
                        Stock(
                            name: quote.longName ?? "Unknown",
                            symbol: quote.symbol,
                            price: quote.regularMarketPrice ?? 0.0,
                            change: quote.regularMarketChangePercent ?? 0.0,
                            open: quote.regularMarketOpen ?? 0.0,
                            high: quote.regularMarketDayHigh ?? 0.0,
                            low: quote.regularMarketDayLow ?? 0.0,
                            volume: quote.regularMarketVolume ?? 0
                        )
                    }
                }
            } catch {
                print("Failed to decode response: \(error)")
            }
        }.resume()
    }
}
 

// MARK: - StockDetailPopup
struct StockDetailPopup: View {
    let stock: Stock
    @State private var chartData: [Double] = []
    @State private var isLoadingChart = true

    var body: some View {
        VStack {
            // Title
            Text(stock.name)
                .font(.largeTitle)
                .padding()

            Text(stock.symbol)
                .font(.title2)
                .foregroundColor(.gray)

            Spacer()

            // Interactive Chart
            if isLoadingChart {
                ProgressView("Loading Chart...")
                    .padding()
            } else {
                ChartView(data: chartData)
                    .frame(height: 300)
                    .padding()
            }

            Spacer()

            // Additional Stock Details
            VStack(alignment: .leading, spacing: 10) {
                Text("Price: $\(String(format: "%.2f", stock.price))")
                Text("Change: \(String(format: "%.2f", stock.change))%")
                    .foregroundColor(stock.change >= 0 ? .green : .red)
                Text("Open: $\(String(format: "%.2f", stock.open))")
                Text("High: $\(String(format: "%.2f", stock.high))")
                Text("Low: $\(String(format: "%.2f", stock.low))")
                Text("Volume: \(stock.volume.formatted())")
            }
            .font(.title3)
            .padding()

            Spacer()
        }
        .onAppear {
            fetchChartData(for: stock.symbol)
        }
        .presentationDetents([.fraction(0.5), .large])
    }

    // Fetch historical chart data
    func fetchChartData(for symbol: String) {
        let urlString = "https://apidojo-yahoo-finance-v1.p.rapidapi.com/stock/v2/get-chart?symbol=\(symbol)&interval=1d&range=1mo"

        var request = URLRequest(url: URL(string: urlString)!)
        request.addValue("2ed59ff31emsh4b4cbd1913d46bep133fadjsn18ddb9cec961", forHTTPHeaderField: "x-rapidapi-key")
        request.addValue("apidojo-yahoo-finance-v1.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching chart data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(ChartResponse.self, from: data)
                DispatchQueue.main.async {
                    self.chartData = decodedResponse.chart.result.first?.indicators.quote.first?.close ?? []
                    self.isLoadingChart = false
                }
            } catch {
                print("Failed to decode chart response: \(error)")
            }
        }.resume()
    }
}


// MARK: - ChartView (Placeholder)
struct ChartView: View {
    let data: [Double]

    var body: some View {
        VStack {
            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(.gray)
            } else {
                LineChartView(
                    data: data,
                    title: "Stock Price",
                   // legend: "Last Month", // Subtitle
                    style: ChartStyle(
                        backgroundColor: .white,
                        accentColor: .blue,
                        gradientColor: GradientColors.blue,
                        textColor: .black,
                        legendTextColor: .gray,
                        dropShadowColor: .gray
                    ),
                    rateValue: (data.last ?? 0) - (data.first ?? 0) > 0 ? 1 : -1
                )
                .padding()
            }
        }
        .frame(height: 500)
    }
}
// MARK: - Models
struct Stock: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let price: Double
    let change: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Int
}

struct QuoteResponse: Decodable {
    let quoteResponse: QuoteResult
}

struct QuoteResult: Decodable {
    let result: [Quote]
}


struct Quote: Decodable {
    let longName: String?
    let symbol: String
    let regularMarketPrice: Double?
    let regularMarketChangePercent: Double?
    let regularMarketOpen: Double?
    let regularMarketDayHigh: Double?
    let regularMarketDayLow: Double?
    let regularMarketVolume: Int?
}

struct ChartResponse: Decodable {
    let chart: ChartResult
}

struct ChartResult: Decodable {
    let result: [ChartIndicators]
}

struct ChartIndicators: Decodable {
    let indicators: ChartIndicator
}

struct ChartIndicator: Decodable {
    let quote: [ChartQuote]
}

struct ChartQuote: Decodable {
    let close: [Double]
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


