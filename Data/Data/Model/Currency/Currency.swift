//
//  Currency.swift
//  Data
//
//  Created by Amisha Italiya on 10/01/25.
//

import Foundation

public struct Currency: Codable {
    public let code: String
    public let name: String
    public let symbol: String
    public let region: String

    private static func getCurrencies() -> [Currency] {
        let allCurrencies = JSONUtils.readJSONFromFile(fileName: "Currencies", type: [Currency].self, bundle: .baseBundle) ?? []
        return allCurrencies
    }

    public static func getCurrentLocalCurrency() -> Currency {
        let allCurrencies = getCurrencies()
        let currentLocal = Locale.current.region?.identifier
        return allCurrencies.first(where: { $0.region == currentLocal }) ??
            (allCurrencies.first ?? Currency(code: "INR", name: "Indian Rupee", symbol: "₹", region: "IN"))
    }
}
