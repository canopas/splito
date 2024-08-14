//
//  CalculateExpensesFunctions.swift
//  Splito
//
//  Created by Amisha Italiya on 24/06/24.
//

import Data
import UIKit
import Combine

// Stores settlement amount with the persons
public struct Settlement {
    let sender: String
    let receiver: String
    let amount: Double
}

public func getTotalSplitAmount(member: String, expense: Expense) -> Double {
    switch expense.splitType {
    case .equally:
        return expense.amount / Double(expense.splitTo.count)
    case .fixedAmount:
        return expense.splitData?[member] ?? 0
    case .percentage:
        let totalPercentage = expense.splitData?.values.reduce(0, +) ?? 0
        return expense.amount * (expense.splitData?[member] ?? 0.0) / totalPercentage
    case .shares:
        let totalShares = expense.splitData?.values.reduce(0, +) ?? 0
        return expense.amount * ((expense.splitData?[member] ?? 0) / totalShares)
    }
}

public func getCalculatedSplitAmount(member: String, expense: Expense) -> Double {
    let splitAmount: Double
    let paidAmount = expense.paidBy[member] ?? 0

    switch expense.splitType {
    case .equally:
        splitAmount = expense.amount / Double(expense.splitTo.count)
    case .fixedAmount:
        splitAmount = expense.splitData?[member] ?? 0.0
    case .percentage:
        let totalPercentage = expense.splitData?.values.reduce(0, +) ?? 0.0
        splitAmount = expense.amount * ((expense.splitData?[member] ?? 0.0) / totalPercentage)
    case .shares:
        let totalShares = expense.splitData?.values.reduce(0, +) ?? 0
        splitAmount = expense.amount * ((expense.splitData?[member] ?? 0) / totalShares)
    }

    if expense.paidBy.keys.contains(member) {
        return paidAmount - (expense.splitTo.contains(member) ? splitAmount : 0)
    } else if expense.splitTo.contains(member) {
        return -splitAmount
    } else {
        return paidAmount
    }
}

// MARK: - Simplified expense calculation

public func calculateExpensesSimplified(userId: String, members: [String], expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var memberBalance: [String: Double] = [:]
    var memberOwingAmount: [String: Double] = [:]

    for expense in expenses {
        for member in members {
            let amount = getCalculatedSplitAmount(member: member, expense: expense)
            memberBalance[member, default: 0] += amount
        }
    }

    let settlements = calculateSettlements(balances: memberBalance)
    for settlement in settlements where settlement.sender == userId || settlement.receiver == userId {
        let memberId = settlement.receiver == userId ? settlement.sender : settlement.receiver
        let amount = settlement.sender == userId ? -settlement.amount : settlement.amount
        memberOwingAmount[memberId, default: 0] = amount
    }

    memberOwingAmount = processTransactions(userId: userId, transactions: transactions, memberOwingAmount: memberOwingAmount)

    return memberOwingAmount.filter { $0.value != 0 }
}

// To decide who owes -> how much amount -> to whom
func calculateSettlements(balances: [String: Double]) -> [Settlement] {
    var creditors: [(String, Double)] = []
    var debtors: [(String, Double)] = []

    // Separate creditors and debtors
    for (user, balance) in balances {
        if balance > 0 {
            creditors.append((user, balance))
        } else if balance < 0 {
            debtors.append((user, -balance)) // Store positive value for easier calculation
        }
    }

    // Sort creditors and debtors by the amount they owe or are owed
    creditors.sort { $0.1 < $1.1 }
    debtors.sort { $0.1 < $1.1 }

    var i = 0 // creditors index
    var j = 0 // debtors index
    var settlements: [Settlement] = []

    // Calculate settlements
    while i < creditors.count && j < debtors.count { // Process all debts
        var (creditor, credAmt) = creditors[i]
        var (debtor, debtAmt) = debtors[j]
        let minAmount = min(credAmt, debtAmt)

        settlements.append(Settlement(sender: debtor, receiver: creditor, amount: minAmount))

        // Update the amounts
        credAmt -= minAmount
        debtAmt -= minAmount

        // If the remaining amount is close to zero, treat it as zero
        creditors[i].1 = round(credAmt * 100) / 100
        debtors[j].1 = round(debtAmt * 100) / 100

        // Move the index forward if someone's balance is settled
        if creditors[i].1 == 0 { i += 1 }
        if debtors[j].1 == 0 { j += 1 }
    }

    return settlements
}

public func processTransactions(userId: String, transactions: [Transactions], memberOwingAmount: [String: Double]) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = memberOwingAmount

    for transaction in transactions {
        if transaction.payerId == userId {
            // If the user is the payer, the receiver owes the user the specified amount
            memberOwingAmount[transaction.receiverId, default: 0.0] += transaction.amount
        } else if transaction.receiverId == userId {
            // If the user is the receiver, the payer owes the user the specified amount
            memberOwingAmount[transaction.payerId, default: 0.0] -= transaction.amount
        }
    }

    return memberOwingAmount.filter { $0.value != 0 }
}

// Used in settings and totals screen's total change in balance calculation
public func calculateMemberBalanceWithTransactions(members: [String], expenses: [Expense], transactions: [Transactions]) -> [String: Double] {
    var amountOweByMember: [String: Double] = [:]

    for expense in expenses {
        for member in members {
            let splitAmount = getCalculatedSplitAmount(member: member, expense: expense)
            amountOweByMember[member, default: 0.0] += splitAmount
        }
    }

    for transaction in transactions {
        amountOweByMember[transaction.payerId, default: 0.0] += transaction.amount
        amountOweByMember[transaction.receiverId, default: 0.0] -= transaction.amount
    }

    return amountOweByMember
}
