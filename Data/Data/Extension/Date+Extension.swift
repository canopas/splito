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

    // 13 Dec
    var shortDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM"
        return dateFormatter.string(from: self)
    }

    // December 2024
    var monthWithYear: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
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

    func isCurrentMonth() -> Bool {
        let calendar = Calendar.current
        let currentDate = Date()
        return calendar.isDate(self, equalTo: currentDate, toGranularity: .month) &&
               calendar.isDate(self, equalTo: currentDate, toGranularity: .year)
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

public extension Date {
    func isToday() -> Bool {
        return Calendar.current.isDateInToday(self)
    }

    func isYesterday() -> Bool {
        return Calendar.current.isDateInYesterday(self)
    }

    func get(_ components: Calendar.Component..., calendar: Calendar = Calendar.current) -> DateComponents {
        return calendar.dateComponents(Set(components), from: self)
    }

    func getDateIn(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}

public extension Date {
    /// This will return string of formatted time with respect to current time in format of **"1 minute ago", "1 hour ago", "10: 30 PM Yesterday",  "10:30 AM  01, Jan" or "10:30 AM 01, Jan 1970"**
    func getFormattedPastTime() -> String {
        let currentTime = Date()
        if isToday() {
            let dateSeconds = Int(self.timeIntervalSince1970)
            let currentTimeSeconds = Int(currentTime.timeIntervalSince1970)
            if (currentTimeSeconds - dateSeconds) < 60 {
                return "Just now"
            } else if (currentTimeSeconds - dateSeconds) < (60*60) {
                return "\(Int(currentTimeSeconds - dateSeconds)/60)" + " " + "min ago"
            } else {
                let hours = Int((currentTimeSeconds - dateSeconds)/(60*60))
                if hours < 2 {
                    return "\(hours)" + " " + "hour ago"
                } else {
                    return "\(hours)" + " " + "hours ago"
                }
            }
        } else if isYesterday() {
            if isTimeIn24HourFormat {
                return "Yesterday" + " " + self.getDateIn(format: "HH:mm")
            } else {
                return "Yesterday" + " " + self.getDateIn(format: "hh:mm a")
            }
        } else {
            let isSameYear = self.get(.year).year == Date().get(.year).year
            if isTimeIn24HourFormat {
                return self.getDateIn(format: isSameYear ? "dd MMM, HH:mm" : "dd MMMM yyyy, HH:mm")
            } else {
                return self.getDateIn(format: isSameYear ? "dd MMM, hh:mm a" : "dd MMMM yyyy, hh:mm a")
            }
        }
    }
}

public var isTimeIn24HourFormat: Bool {
    let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)
    return dateFormat == "HH"
}
