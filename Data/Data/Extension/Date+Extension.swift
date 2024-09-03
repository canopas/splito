//
//  Date+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 10/04/24.
//

import Foundation

public extension Date {

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

    var dayAndMonthText: (day: String, month: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let day = formatter.string(from: self)

        formatter.dateFormat = "MMM"
        let month = formatter.string(from: self)

        return (day, month)
    }

    var nameOfMonth: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: self).capitalized
    }

    func startOfMonth() -> Date { // give start date of month
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? Date()
    }

    func endOfMonth() -> Date {  // give end date of month
        if let endOfMonth = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth()) {
            return endOfMonth
        }
        return Date()
    }
}
