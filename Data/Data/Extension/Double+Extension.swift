//
//  Double+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 10/04/24.
//

import Foundation

public extension Double {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current

        if let formattedAmount = formatter.string(from: NSNumber(value: self)) {
            return formattedAmount.hasPrefix("-") ? String(formattedAmount.dropFirst()) : formattedAmount
        } else {
            return String(format: "%.2f", self.rounded())  // Fallback to a basic decimal format
        }
    }

    func formattedCurrencyWithSign(_ sign: String) -> String {
        let amount: String
        let formatter = NumberFormatter()
        formatter.locale = Locale.current

        if let formattedAmount = formatter.string(from: NSNumber(value: self)) {
            amount = formattedAmount
        } else {
            amount = String(format: "%.2f", self.rounded())  // Fallback to a basic decimal format
        }
        return sign + " " + amount
    }

    var formattedCurrencyWithSign: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current

        if let formattedAmount = formatter.string(from: NSNumber(value: self)) {
            return formattedAmount
        } else {
            return String(format: "%.2f", self.rounded())  // Fallback to a basic decimal format
        }
    }

    /// Rounds the `Double` value to the specified number of decimal places
    func rounded(to decimals: Int) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (self * multiplier).rounded() / multiplier
    }
}
