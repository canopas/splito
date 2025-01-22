//
//  Double+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 10/04/24.
//

import Foundation

public extension Double {

    func formattedCurrency(_ code: String?, _ showSign: Bool = false) -> String {
        let amount: String
        let formatter = NumberFormatter()
        formatter.locale = Locale.current

        if let formattedAmount = formatter.string(from: NSNumber(value: self)) {
            amount = formattedAmount.hasPrefix("-") ? String(formattedAmount.dropFirst()) : formattedAmount
        } else {
            amount = String(format: "%.2f", self.rounded())  // Fallback to a basic decimal format
        }

        let currencySymbol = Currency.getCurrencyFromCode(code).symbol
        if showSign {
            let sign = self < 0 ? "-" : ""
            return currencySymbol.isEmpty ? "\(sign)\(amount)" : "\(sign)\(currencySymbol) \(amount)"
        } else {
            return currencySymbol.isEmpty ? amount : (currencySymbol + " " + amount)
        }
    }

    /// Rounds the `Double` value to the specified number of decimal places
    func rounded(to decimals: Int) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (self * multiplier).rounded() / multiplier
    }
}
