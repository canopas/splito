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

public enum DataUpdateType {
    case Add
	case Update(oldExpense: Expense)
    case Delete
}

/// It will return member's total split amount from the total expense
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

/// It will return the owing amount to the member for that expense that he have to get or pay back
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

public func getUpdatedMemberBalance(expense: Expense, group: Groups, updateType: DataUpdateType) -> [GroupMemberBalance] {
    var memberBalance = group.balance
    for member in group.members {
        let newSplitAmount = getCalculatedSplitAmount(member: member, expense: expense)
        if group.balance.contains(where: { $0.id == member }) {
            if let index = group.balance.firstIndex(where: { $0.id == member }) {
                switch updateType {
                case .Add:
                    memberBalance[index].balance += newSplitAmount
                case .Update(let oldExpense):
					let oldSplitAmount = getCalculatedSplitAmount(member: member, expense: oldExpense)
					memberBalance[index].balance -= oldSplitAmount
                    memberBalance[index].balance += newSplitAmount
                case .Delete:
                    memberBalance[index].balance -= newSplitAmount
                }
            }
        } else {
            memberBalance.append(GroupMemberBalance(id: member, balance: newSplitAmount))
        }
    }
    return memberBalance
}

// MARK: - Simplified expense calculation

public func calculateExpensesSimplified(userId: String, memberBalances: [GroupMemberBalance]) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = [:]

    let settlements = calculateSettlements(balances: memberBalances)
    for settlement in settlements where settlement.sender == userId || settlement.receiver == userId {
        let memberId = settlement.receiver == userId ? settlement.sender : settlement.receiver
        let amount = settlement.sender == userId ? -settlement.amount : settlement.amount
        memberOwingAmount[memberId, default: 0] = amount
    }

    return memberOwingAmount.filter { $0.value != 0 }
}

// To decide who owes -> how much amount -> to whom
func calculateSettlements(balances: [GroupMemberBalance]) -> [Settlement] {
    var creditors: [(String, Double)] = []
    var debtors: [(String, Double)] = []

    // Separate creditors and debtors
    for balance in balances {
        if balance.balance > 0 {
            creditors.append((balance.id, balance.balance))
        } else if balance.balance < 0 {
            debtors.append((balance.id, -balance.balance)) // Store positive value for easier calculation
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
