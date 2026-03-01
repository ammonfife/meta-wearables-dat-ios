/*
 * CoinResultView.swift
 * Overlay card showing coin identification results from lkup.info.
 * Slides up from bottom with pricing tiers and auto-dismisses after 10s.
 */

import SwiftUI

struct CoinResultView: View {
    let coin: CoinIdentification
    let onDismiss: () -> Void

    private let gold = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coin.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            if let year = coin.year {
                                TagPill(text: year)
                            }
                            if let grade = coin.grade {
                                TagPill(text: grade)
                            }
                            if let denomination = coin.denomination {
                                TagPill(text: denomination)
                            }
                        }
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }

                if let metal = coin.metal {
                    Text(metal)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Pricing tiers
                if let prices = coin.prices {
                    Divider().background(Color.gray.opacity(0.3))

                    VStack(spacing: 10) {
                        if let retail = prices.retail {
                            PriceRow(label: "Retail", value: retail, highlight: true, gold: gold)
                        }
                        if let guide = prices.guide {
                            PriceRow(label: "Price Guide", value: guide, gold: gold)
                        }
                        if let market = prices.marketplaceAvg {
                            PriceRow(label: "Market Avg", value: market, gold: gold)
                        }
                        if let base = prices.base {
                            PriceRow(label: "Base", value: base, gold: gold)
                        }
                        if let melt = prices.melt {
                            PriceRow(label: "Melt", value: melt, gold: gold)
                        }
                    }
                }

                // lkup.info attribution
                HStack {
                    Spacer()
                    Text("lkup.info")
                        .font(.caption2)
                        .foregroundColor(gold.opacity(0.6))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(gold.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.15))
            .cornerRadius(6)
            .foregroundColor(.white.opacity(0.8))
    }
}

struct PriceRow: View {
    let label: String
    let value: Double
    var highlight: Bool = false
    let gold: Color

    var body: some View {
        HStack {
            Text(label)
                .font(highlight ? .subheadline.bold() : .subheadline)
                .foregroundColor(highlight ? .white : .gray)
            Spacer()
            Text(String(format: "$%.2f", value))
                .font(highlight ? .title3.bold() : .subheadline.bold())
                .foregroundColor(highlight ? gold : .white)
        }
    }
}
