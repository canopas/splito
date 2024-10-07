//
//  Notification+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 05/09/24.
//

import Foundation

public extension Notification.Name {
    static let addExpense = Notification.Name("addExpense")
    static let updateExpense = Notification.Name("updateExpense")
    static let deleteExpense = Notification.Name("deleteExpense")

    static let addTransaction = Notification.Name("addTransaction")
    static let updateTransaction = Notification.Name("updateTransaction")
    static let deleteTransaction = Notification.Name("deleteTransaction")

    static let joinGroup = Notification.Name("joinGroup")

    static let addGroup = Notification.Name("addGroup")
    static let updateGroup = Notification.Name("updateGroup")
    static let deleteGroup = Notification.Name("deleteGroup")
    static let leaveGroup = Notification.Name("leaveGroup")
}
