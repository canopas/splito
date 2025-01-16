//
//  AddAmountView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 13/01/25.
//

import SwiftUI
import BaseStyle

struct AddAmountView: View {

    @Binding var amount: Double
    @Binding var showCurrencyPicker: Bool

    @State private var amountString: String = ""

    var selectedCurrencyCode: String
    var isAmountFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Text(selectedCurrencyCode)
                .font(.Header3())
                .foregroundStyle(primaryText)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(inversePrimaryText)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTouchGesture {
                    showCurrencyPicker = true
                }

            TextField("0.00", text: $amountString)
                .font(.Header1())
                .tint(primaryColor)
                .focused(isAmountFocused)
                .autocorrectionDisabled()
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .tint(amountString.isEmpty ? outlineColor : primaryText)
                .onChange(of: amountString) { newValue in
                    formatAmount(newValue: newValue)
                }
                .onAppear {
                    amountString = amount == 0 ? "" : String(format: "%.2f", amount)
                }
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1)
        }
    }

    private func formatAmount(newValue: String) {
        let numericInput = newValue.trimmingCharacters(in: .whitespaces)
        amountString = numericInput.isEmpty ? "" : numericInput
        amount = Double(numericInput) ?? 0
    }
}
