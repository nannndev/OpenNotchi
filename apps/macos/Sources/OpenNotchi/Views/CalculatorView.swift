import AppKit
import SwiftUI

/// Type math ("2jt*12%", "sqrt(2)") or a conversion ("100 usd to idr"); the answer updates as you type.
struct CalculatorView: View {
    @State private var input = ""
    @State private var history: [String] = []
    /// Yahoo forex symbol ("USDIDR=X") → quote, fetched on demand.
    @State private var rates: [String: Quote] = [:]
    @FocusState private var focused: Bool
    @AppStorage("calcScientific") private var scientific = false

    /// Label → text it types; "=", "C" and "⌫" are handled in `press`.
    private static let basicKeys = [
        ["C", "⌫", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["00", "0", ".", "="],
    ]
    private static let scienceKeys = [
        ["sin", "cos", "tan"], ["log", "ln", "√"], ["x²", "^", "π"], ["(", ")", "e"], ["abs", "rb", "jt"],
    ]

    private static let board = ["USD", "EUR", "SGD", "JPY", "CNY", "SAR"]
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var conversion: Calculator.Conversion? { Calculator.parseConversion(input) }

    /// What the answer box shows. nil when the input isn't valid yet; "…" while a conversion's rate is loading.
    private var answer: Calculator.Answer? {
        if let smart = Calculator.smart(input) { return smart }
        if let c = conversion {
            let rate = c.from == c.to ? 1 : rates[Calculator.rateSymbol(from: c.from, to: c.to)]?.price
            guard let rate else { return Calculator.Answer(text: "…", value: nil) }
            let value = c.amount * rate
            return Calculator.Answer(text: Calculator.format(value, currency: c.to) + " " + c.to, value: value)
        }
        return Calculator.evaluate(input).map { Calculator.Answer(text: Calculator.format($0), value: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("15% dari 200rb · 100 usd to idr · 5 km to mi · hari sampai 25 des", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .focused($focused)
                    .onSubmit(commit)
                if let answer {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(answer.text, forType: .string)
                    } label: {
                        Text("= " + answer.text)
                            .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .buttonStyle(.plain)
                    .help("Copy result")
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))

            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 4) {
                    Picker("", selection: $scientific) {
                        Text("Basic").tag(false)
                        Text("Scientific").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    HStack(spacing: 6) {
                        if scientific { keypad(Self.scienceKeys, tint: .white.opacity(0.04)) }
                        keypad(Self.basicKeys, tint: .white.opacity(0.08))
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Live · 1 → IDR").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(Self.board, id: \.self) { code in
                            let q = rates[Calculator.rateSymbol(from: code, to: "IDR")]
                            Button {
                                input = "1 \(code.lowercased()) to idr"
                            } label: {
                                HStack(spacing: 4) {
                                    Text(code).font(.system(size: 10, weight: .bold, design: .rounded))
                                    Spacer(minLength: 0)
                                    Text(q.map { Calculator.format($0.price, currency: "IDR") } ?? "—")
                                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                                        .foregroundStyle(q.map { $0.change >= 0 ? Color.green : .red } ?? .secondary)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Yahoo Finance · refreshes every 30s").font(.system(size: 8)).foregroundStyle(.quaternary)
                    Text("History").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(history, id: \.self) { line in
                                Button(line) {
                                    input = String(line.split(separator: "=").first ?? "").trimmingCharacters(in: .whitespaces)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: 220)
            }
        }
        .onAppear {
            focused = true
            refresh()
        }
        .onReceive(tick) { _ in refresh() }
        .onChange(of: conversion) { _, c in
            if let c, c.from != c.to { load(Calculator.rateSymbol(from: c.from, to: c.to)) }
        }
    }

    private func keypad(_ rows: [[String]], tint: Color) -> some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(key == "=" ? Color.orange : "÷×−+".contains(key) ? .white.opacity(0.16) : tint))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func press(_ key: String) {
        switch key {
        case "=": commit()
        case "C": input = ""
        case "⌫": if !input.isEmpty { input.removeLast() }
        case "÷": input += "/"
        case "×": input += "*"
        case "−": input += "-"
        case "π": input += "pi"
        case "x²": input += "^2"
        case "√": input += "sqrt("
        case "sin", "cos", "tan", "log", "ln", "abs": input += key + "("
        default: input += key
        }
        focused = true
    }

    private func commit() {
        guard let answer, answer.text != "…" else { return }
        history.removeAll { $0.hasPrefix(input + " =") }
        history.insert("\(input) = \(answer.text)", at: 0)
        history = Array(history.prefix(20))
        // Keep chaining off the raw number (not the locale-formatted text); dates leave the input as is.
        if let value = answer.value { input = "\(value)" }
    }

    private func refresh() {
        Self.board.forEach { load(Calculator.rateSymbol(from: $0, to: "IDR")) }
        if let c = conversion, c.from != c.to { load(Calculator.rateSymbol(from: c.from, to: c.to)) }
    }

    private func load(_ symbol: String) {
        MarketManager.fetch(symbol) { quote in
            guard let quote else { return }
            DispatchQueue.main.async { rates[symbol] = quote }
        }
    }
}
