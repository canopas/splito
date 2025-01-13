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

    var currencies: [Currency]
    @Binding var selectedCurrency: Currency
    @Binding var isPresented: Bool

    @State private var searchedCurrency: String = ""
    @FocusState private var isFocused: Bool

    private var filteredCurrencies: [Currency] {
        currencies.filter { currency in
            searchedCurrency.isEmpty ? true : currency.name.lowercased().contains(searchedCurrency.lowercased()) ||
            currency.code.lowercased().contains(searchedCurrency.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                NavigationBarTopView(title: "Select Currency", leadingButton: EmptyView(),
                                     trailingButton: DismissButton(padding: (0, 0), foregroundColor: primaryText,
                                                                   onDismissAction: { dismiss() })
                                        .fontWeight(.regular)
                )

                SearchBar(text: $searchedCurrency, isFocused: $isFocused, placeholder: "Search")
                    .padding(.vertical, -7)
                    .padding(.horizontal, 3)
                    .overlay(content: {
                        RoundedRectangle(cornerRadius: 12).stroke(outlineColor, lineWidth: 1)
                    })
                    .focused($isFocused)
                    .onAppear { isFocused = true }
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 16)

            if filteredCurrencies.isEmpty {
                CurrencyNotFoundView(searchedCurrency: searchedCurrency)
            } else {
                List(currencies, id: \.self) { currency in
                    CurrencyCellView(currency: currency) {
                        selectedCurrency = currency
                        isPresented = false
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct CurrencyNotFoundView: View {

    let searchedCurrency: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("No country found for \"\(searchedCurrency)\"!")
                .font(.subTitle1())
                .foregroundStyle(disableText)
                .padding(.bottom, 60)
            Spacer()
        }
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}

private struct CurrencyCellView: View {

    let currency: Currency
    let onCellSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(currency.symbol)
                    .font(.Header4())
                    .frame(width: 50)

                Text(currency.name)
                    .font(.body1(16))
            }
            .padding(.horizontal, 10)
            .foregroundStyle(primaryText)

            Divider()
                .frame(height: 1)
                .background(dividerColor)
                .padding(.vertical, 14)
        }
        .contentShape(Rectangle())
        .onTouchGesture { onCellSelect() }
    }
}
