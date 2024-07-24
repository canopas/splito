//
//  CalculateExpensesFunctions.swift
//  Splito
//
//  Created by Amisha Italiya on 24/06/24.
//

import Data
import Combine

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
        return expense.amount * (Double(expense.splitData?[member] ?? 0)) / Double(totalShares)
    }
}

public func getCalculatedSplitAmount(member: String, expense: Expense) -> Double {
    let totalAmount = expense.amount
    let paidAmount = expense.paidBy[member] ?? 0

    // If the member is not part of the split and has paid, then return the paid amount
    if !expense.splitTo.contains(member) && expense.paidBy.keys.contains(member) {
        return paidAmount
    }

    switch expense.splitType {
    case .equally:
        let splitAmount = totalAmount / Double(expense.splitTo.count)
        return paidAmount - splitAmount
    case .fixedAmount:
        let splitAmount = expense.splitData?[member] ?? 0.0
        return paidAmount - splitAmount
    case .percentage:
        let totalPercentage = expense.splitData?.values.reduce(0, +) ?? 0.0
        let splitAmount = totalAmount * (expense.splitData?[member] ?? 0.0 / totalPercentage)
        return paidAmount - splitAmount
    case .shares:
        let totalShares = expense.splitData?.values.reduce(0, +) ?? 0
        let splitAmount = totalAmount * (expense.splitData?[member] ?? 0 / totalShares)
        return paidAmount - splitAmount
    }
}

public func getCalculatedSplitAmount2(member: String, expense: Expense) -> Double {

    var splitAmount = 0.0
    let totalAmount = expense.amount
    let paidAmount = expense.paidBy[member] ?? 0

    switch expense.splitType {
    case .equally:
        let overallSplitAmount = totalAmount / Double(expense.splitTo.count)
        if expense.paidBy.keys.contains(member) {
            splitAmount = paidAmount - (expense.splitTo.contains(member) ? overallSplitAmount : 0)
        } else if expense.splitTo.contains(member) {
            splitAmount = -overallSplitAmount
        } else {
            splitAmount = paidAmount
        }
    case .fixedAmount:
        let overallSplitAmount = expense.splitData?[member] ?? 0.0

        if expense.paidBy.keys.contains(member) {
            splitAmount = paidAmount - (expense.splitTo.contains(member) ? overallSplitAmount : 0)
        } else if expense.splitTo.contains(member) {
            splitAmount = overallSplitAmount
        } else {
            splitAmount = paidAmount
        }
    case .percentage:
        break
    case .shares:
        break
    }

    return splitAmount
}

// MARK: - Non Simplified expense calculation

public func calculateExpensesNonSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = [:]
    var userOwingAmount: [String: Double] = [:]

    for expense in expenses {
        if expense.paidBy.keys.contains(userId) {
            for member in expense.splitTo where member != userId {
                let splitAmount = getCalculatedSplitAmount(member: member, expense: expense)
                userOwingAmount[member, default: 0.0] += splitAmount
            }
        } else if expense.splitTo.contains(userId) {
            for (payerId, _) in expense.paidBy where payerId != userId {
                let splitAmount = getCalculatedSplitAmount(member: userId, expense: expense)
                userOwingAmount[payerId, default: 0.0] -= splitAmount
            }
        }
    }

    memberOwingAmount = processTransactions(userId: userId, transactions: transactions, memberOwingAmount: userOwingAmount)

    return memberOwingAmount.filter { $0.value != 0 }
}

public func processTransactions(userId: String, transactions: [Transactions], memberOwingAmount: [String: Double]) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = memberOwingAmount

    for transaction in transactions {
        if transaction.payerId == userId {
            // If the user is the payer, the receiver owes the user the specified amount
            memberOwingAmount[transaction.receiverId, default: 0.0] -= transaction.amount
        } else if transaction.receiverId == userId {
            // If the user is the receiver, the payer owes the user the specified amount
            memberOwingAmount[transaction.payerId, default: 0.0] += transaction.amount
        }
    }
    return memberOwingAmount.filter { $0.value != 0 }
}

// MARK: - Simplified expense calculation

public func calculateExpensesSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var ownAmounts: [String: Double] = [:]
    var memberOwingAmount: [String: Double] = [:]

    for expense in expenses {
        for (payerId, paidAmount) in expense.paidBy {
            ownAmounts[payerId, default: 0.0] += paidAmount
        }

        for member in expense.splitTo {
            let splitAmount = getCalculatedSplitAmount(member: member, expense: expense)
            ownAmounts[member, default: 0.0] -= splitAmount
        }
    }

    let debts = settleDebts(users: ownAmounts)
    for debt in debts where debt.0 == userId || debt.1 == userId {
        memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
    }

    memberOwingAmount = processTransactions(userId: userId, transactions: transactions, memberOwingAmount: memberOwingAmount)

    return memberOwingAmount.filter { $0.value != 0 }
}

public func settleDebts(users: [String: Double]) -> [(String, String, Double)] {
    var creditors: [(String, Double)] = []
    var debtors: [(String, Double)] = []

    // Separate users into creditors and debtors
    for (user, balance) in users {
        if balance > 0 {
            creditors.append((user, balance))
        } else if balance < 0 {
            debtors.append((user, -balance)) // Store as positive for ease of calculation
        }
    }

    // Sort creditors and debtors by the amount they owe or are owed
    creditors.sort { $0.1 < $1.1 }
    debtors.sort { $0.1 < $1.1 }

    var transactions: [(String, String, Double)] = [] // (debtor, creditor, amount)
    var cIdx = 0
    var dIdx = 0

    while cIdx < creditors.count && dIdx < debtors.count { // Process all debts
        let (creditor, credAmt) = creditors[cIdx]
        let (debtor, debtAmt) = debtors[dIdx]
        let minAmt = min(credAmt, debtAmt)

        transactions.append((debtor, creditor, minAmt)) // Record the transaction
        // Update the amounts

        creditors[cIdx] = (creditor, credAmt - minAmt)
        debtors[dIdx] = (debtor, debtAmt - minAmt)

        // Move the index forward if someone's balance is settled
        if creditors[cIdx].1 == 0 { cIdx += 1 }
        if debtors[dIdx].1 == 0 { dIdx += 1 }
    }

    return transactions
}

// Used in settings and totals screen's total change in balance calculation
public func calculateTransactionsWithExpenses(expenses: [Expense], transactions: [Transactions]) -> [String: Double] {
    var amountOweByMember: [String: Double] = [:]

    for expense in expenses {
        for (payerId, paidAmount) in expense.paidBy {
            amountOweByMember[payerId, default: 0.0] += paidAmount
        }

        for member in expense.splitTo {
            let splitAmount = getCalculatedSplitAmount(member: member, expense: expense)
            amountOweByMember[member, default: 0.0] -= splitAmount
        }
    }

    for transaction in transactions {
        amountOweByMember[transaction.payerId, default: 0.0] += transaction.amount
        amountOweByMember[transaction.receiverId, default: 0.0] -= transaction.amount
    }

    return amountOweByMember
}
