//
//  CalculateExpensesFunctions.swift
//  Splito
//
//  Created by Amisha Italiya on 24/06/24.
//

import Data
import Combine

public func calculateExpensesNonSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = [:]
    var owesToUser: [String: Double] = [:]
    var owedByUser: [String: Double] = [:]

    for expense in expenses {
        let splitAmount = calculateSplitAmount(member: userId, expense: expense)

        if expense.paidBy == userId {
            for member in expense.splitTo where member != userId {
                owesToUser[member, default: 0.0] += splitAmount
            }
        } else if expense.splitTo.contains(userId) {
            owedByUser[expense.paidBy, default: 0.0] += splitAmount
        }
    }

    (owesToUser, owedByUser) = processTransactionsNonSimply(userId: userId, transactions: transactions, owesToUser: owesToUser, owedByUser: owedByUser)

    owesToUser.forEach { userId, owesAmount in
        memberOwingAmount[userId, default: 0.0] = owesAmount
    }
    owedByUser.forEach { userId, owedAmount in
        memberOwingAmount[userId, default: 0.0] = (memberOwingAmount[userId] ?? 0) - owedAmount
    }

    return memberOwingAmount.filter { $0.value != 0 }
}

public func processTransactionsNonSimply(userId: String, transactions: [Transactions], owesToUser: [String: Double], owedByUser: [String: Double]) -> (owesToUser: [String: Double], owedByUser: [String: Double]) {

    var owesToUser = owesToUser
    var owedByUser = owedByUser

    for transaction in transactions {
        let payer = transaction.payerId
        let receiver = transaction.receiverId
        let amount = transaction.amount

        if transaction.payerId == userId {
            if owedByUser[receiver] != nil {
                // If the receiver owes money to the user, increase the amount the user owes to the receiver
                owesToUser[transaction.receiverId, default: 0.0] += amount
            } else {
                // Otherwise decrease the amount the user owes to the payer
                owedByUser[transaction.payerId, default: 0.0] -= amount
            }
        } else if transaction.receiverId == userId {
            if owesToUser[payer] != nil {
                // If the payer owes money to the user, increase the amount the payer owes to the user
                owedByUser[transaction.payerId, default: 0.0] += amount
            } else {
                // Otherwise set the amount the payer owes to the user
                owesToUser[payer] = -amount
            }
        }
    }
    return (owesToUser, owedByUser)
}

public func calculateExpensesSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var ownAmounts: [String: Double] = [:]
    var memberOwingAmount: [String: Double] = [:]

    for expense in expenses {
        ownAmounts[expense.paidBy, default: 0.0] += expense.amount

        let splitAmount = calculateSplitAmount(member: userId, expense: expense)
        for member in expense.splitTo {
            ownAmounts[member, default: 0.0] -= splitAmount
        }
    }

    let debts = settleDebts(users: ownAmounts)
    for debt in debts where debt.0 == userId || debt.1 == userId {
        memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
    }

    memberOwingAmount = processTransactionsSimply(userId: userId, transactions: transactions, memberOwingAmount: memberOwingAmount)

    return memberOwingAmount.filter { $0.value != 0 }
}

public func processTransactionsSimply(userId: String, transactions: [Transactions], memberOwingAmount: [String: Double]) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = memberOwingAmount

    for transaction in transactions {
        let payer = transaction.payerId
        let receiver = transaction.receiverId
        let amount = transaction.amount

        if payer == userId {
            // If the user is the payer, the receiver owes the user the specified amount
            memberOwingAmount[receiver, default: 0.0] += amount
        } else if receiver == userId {
            // If the user is the receiver, the payer owes the user the specified amount
            memberOwingAmount[payer, default: 0.0] -= amount
        }
    }
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

public func calculateSplitAmount(member: String, expense: Expense) -> Double {
    let splitAmount: Double

    switch expense.splitType {
    case .equally:
        splitAmount = expense.amount / Double(expense.splitTo.count)
    case .percentage:
        let totalPercentage = expense.splitData?.values.reduce(0, +) ?? 0.0
        splitAmount = expense.amount * (expense.splitData?[member] ?? 0.0) / totalPercentage
    case .shares:
        let totalShares = expense.splitData?.values.reduce(0, +) ?? 0
        splitAmount = expense.amount * (Double(expense.splitData?[member] ?? 0)) / Double(totalShares)
    }

    return splitAmount
}

// Used in settings and totals screen's total change in balance calculation
public func calculateTransactionsWithExpenses(expenses: [Expense], transactions: [Transactions]) -> [String: Double] {
    var amountOweByMember: [String: Double] = [:]

    for expense in expenses {
        amountOweByMember[expense.paidBy, default: 0.0] += expense.amount

        for member in expense.splitTo {
            let splitAmount = calculateSplitAmount(member: member, expense: expense)
            amountOweByMember[member, default: 0.0] -= splitAmount
        }
    }

    for transaction in transactions {
        amountOweByMember[transaction.payerId, default: 0.0] += transaction.amount
        amountOweByMember[transaction.receiverId, default: 0.0] -= transaction.amount
    }

    return amountOweByMember
}
