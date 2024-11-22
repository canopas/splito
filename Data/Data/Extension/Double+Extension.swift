//
//  Double+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 10/04/24.
//

import Foundation

public extension Double {
    func formattedCurrency(removeMinusSign: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current

        if let formattedAmount = formatter.string(from: NSNumber(value: self)) {
            if removeMinusSign && formattedAmount.hasPrefix("-") {
                return String(formattedAmount.dropFirst())
            }
            return formattedAmount
        } else {
            return String(format: "%.2f", self.rounded())  // Fallback to a basic decimal format
        }
    }

    var formattedCurrency: String {
        return formattedCurrency(removeMinusSign: true)
    }

    var formattedCurrencyWithSign: String {
        return formattedCurrency(removeMinusSign: false)
    }
}
