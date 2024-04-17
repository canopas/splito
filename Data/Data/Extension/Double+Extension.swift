//
//  Double+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 10/04/24.
//

import Foundation

public extension Double {
    func formattedCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current

        if let formattedAmount = formatter.string(from: NSNumber(value: self)) {
            return formattedAmount.hasPrefix("-") ? String(formattedAmount.dropFirst()) : formattedAmount
        } else {
            return String(format: "%.2f", self.rounded())  // Fallback to a basic decimal format
        }
    }
}
