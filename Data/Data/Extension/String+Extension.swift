//
//  String+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 18/03/24.
//

import Foundation

public extension String {

    func encryptHexCode() -> String {
        let key: UInt8 = 42 // Choose a simple key
        guard let data = data(using: .utf8) else { return "" }
        let encryptedData = data.map { $0 ^ key }
        return encryptedData.map { String(format: "%02hhx", $0) }.joined()
    }

    func decryptHexCode() -> String? {
        let key: UInt8 = 42 // Use the same key as encryption
        let hexString = self
        var decryptedData = Data()

        var index = hexString.startIndex
        while index < hexString.endIndex {
            let endIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            let hexByte = hexString[index..<endIndex]

            guard let byte = UInt8(hexByte, radix: 16) else { return nil }
            decryptedData.append(byte ^ key)

            index = endIndex
        }
        return String(data: decryptedData, encoding: .utf8)
    }
}
