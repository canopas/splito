//
//  Currency.swift
//  Data
//
//  Created by Amisha Italiya on 10/01/25.
//

import Foundation

public struct Currency: Decodable, Hashable {
    public let code: String
    public let name: String
    public let symbol: String
    public let region: String

    public static var defaultCurrency = Currency(code: "INR", name: "Indian Rupee", symbol: "₹", region: "IN")

    public init(code: String, name: String, symbol: String, region: String) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.region = region
    }

    public static func getAllCurrencies() -> [Currency] {
        let allCurrencies = JSONUtils.readJSONFromFile(fileName: "Currencies", type: [Currency].self, bundle: .dataBundle) ?? []
        return allCurrencies
    }

    public static func getCurrencyFromCode(_ code: String?) -> Currency {
        let allCurrencies = getAllCurrencies()
        let currency = allCurrencies.first(where: { $0.code == code }) ?? defaultCurrency
        return currency
    }

    public static func getCurrentLocalCurrency() -> Currency {
        let allCurrencies = getAllCurrencies()
        let currentLocal = Locale.current.region?.identifier
        let currency = allCurrencies.first(where: { $0.region == currentLocal }) ??
            (allCurrencies.first ?? defaultCurrency)
        return currency
    }
}
