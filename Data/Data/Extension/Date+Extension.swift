//
//  Date+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 10/04/24.
//

import Foundation

public extension Date {

    // Mar \n 10
    var shortDateWithNewLine: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM\ndd"
        return dateFormatter.string(from: self)
    }

    // 10 March 2024
    var longDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        return dateFormatter.string(from: self)
    }

    var millisecondsSince1970: Int {
        Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    var secondsSince1970: Int {
        Int((self.timeIntervalSince1970).rounded())
    }
}
