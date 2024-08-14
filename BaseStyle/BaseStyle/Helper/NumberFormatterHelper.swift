//
//  NumberFormatterHelper.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 11/07/24.
//

import Foundation

public var numberFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.usesGroupingSeparator = false
    formatter.zeroSymbol  = ""
    return formatter
}
