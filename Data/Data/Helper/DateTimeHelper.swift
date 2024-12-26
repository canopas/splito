//
//  DateTimeHelper.swift
//  Data
//
//  Created by Amisha Italiya on 25/12/24.
//

import Foundation

public func sortMonthYearStrings(_ s1: String, _ s2: String) -> Bool {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM yyyy"

    guard let date1 = dateFormatter.date(from: s1),
          let date2 = dateFormatter.date(from: s2) else {
        return false
    }

    let components1 = Calendar.current.dateComponents([.year, .month], from: date1)
    let components2 = Calendar.current.dateComponents([.year, .month], from: date2)

    // Compare years first
    if components1.year != components2.year {
        return (components1.year ?? 0) > (components2.year ?? 0)
    }
    // If years are the same, compare months
    else {
        return (components1.month ?? 0) > (components2.month ?? 0)
    }
}
