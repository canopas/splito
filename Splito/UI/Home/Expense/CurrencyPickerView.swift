//
//  CurrencyPickerView.swift
//  Splito
//
//  Created by Amisha Italiya on 13/01/25.
//

import Data
import SwiftUI
import BaseStyle

struct CurrencyPickerView: View {

    @Environment(\.dismiss) var dismiss

    @Binding var selectedCurrency: Currency
    @Binding var isPresented: Bool

    var supportedCurrencies: [Currency] = []

    @State private var searchedCurrency: String = ""
    @FocusState private var isFocused: Bool

    private var filteredCurrencies: [Currency] {
        // Get all currencies and filter based on availability and search text
        let currencies = supportedCurrencies.isEmpty ? Currency.getAllCurrencies() : supportedCurrencies

        guard !searchedCurrency.isEmpty else { return currencies }
        return currencies.filter { currency in
            currency.name.lowercased().contains(searchedCurrency.lowercased()) ||
            currency.code.lowercased().contains(searchedCurrency.lowercased()) ||
            currency.symbol.lowercased().contains(searchedCurrency.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VSpacer(24)

            SearchBar(text: $searchedCurrency, isFocused: $isFocused, placeholder: "Search currency")
                .padding(.vertical, -7)
                .padding(.horizontal, 3)
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 12).stroke(outlineColor, lineWidth: 1)
                })
                .focused($isFocused)
                .onAppear { isFocused = true }
                .padding(.horizontal, 16)

            VSpacer(4)

            if !supportedCurrencies.isEmpty {
                Text("Supported currencies")
                    .font(.subTitle3())
                    .foregroundStyle(disableText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, 24)
            }

            if filteredCurrencies.isEmpty {
                CurrencyNotFoundView(searchedCurrency: searchedCurrency)
            } else {
                List(filteredCurrencies, id: \.self) { currency in
                    CurrencyCellView(currency: currency, isLastCurrency: filteredCurrencies.last == currency) {
                        selectedCurrency = currency
                        isPresented = false
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(surfaceColor)
                }
                .listStyle(.plain)
            }
        }
        .background(surfaceColor)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Choose a currency")
            }
        }
    }
}

private struct CurrencyNotFoundView: View {

    let searchedCurrency: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()
            Text("No currency found for \"\(searchedCurrency)\"!")
                .font(.subTitle1())
                .foregroundStyle(disableText)
                .padding(.bottom, 60)
                .padding(.horizontal, 16)
            Spacer()
        }
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}

private struct CurrencyCellView: View {

    let currency: Currency
    let isLastCurrency: Bool

    let onCellSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("\(currency.name) (\(currency.symbol))")
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)

                Spacer()

                Text(currency.code)
                    .font(.body1())
                    .foregroundStyle(disableText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            if !isLastCurrency {
                Divider()
                    .frame(height: 1)
                    .background(dividerColor)
            }
        }
        .contentShape(Rectangle())
        .onTouchGesture { onCellSelect() }
    }
}
