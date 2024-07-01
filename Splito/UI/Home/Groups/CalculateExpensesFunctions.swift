//
//  CalculateExpensesFunctions.swift
//  Splito
//
//  Created by Amisha Italiya on 24/06/24.
//

import Data
import Combine

public func calculateExpensesNonSimplify(userId: String, expenses: [Expense], transactions: [Transactions]) -> ([String: Double]) {

    var owesToUser: [String: Double] = [:]
    var owedByUser: [String: Double] = [:]
    var memberOwingAmount: [String: Double] = [:]

    for expense in expenses {
        switch expense.splitType {
        case .equally:
            let splitAmount = expense.amount / Double(expense.splitTo.count)
            if expense.paidBy == userId {
                // If the user paid for the expense, calculate how much each member owes the user
                for member in expense.splitTo where member != userId {
                    owesToUser[member, default: 0.0] += splitAmount
                }
            } else if expense.splitTo.contains(userId) {
                // If the user is one of the members who should split the expense, calculate how much the user owes to the payer
                owedByUser[expense.paidBy, default: 0.0] += splitAmount
            }

        case .percentage:
            let totalPercentage = expense.splitData?.values.reduce(0, +) ?? 0.0
            for (member, percentage) in expense.splitData ?? [:] {
                let splitAmount = (expense.amount * (percentage / totalPercentage))
                if expense.paidBy == userId {
                    if member != userId {
                        owesToUser[member, default: 0.0] += splitAmount
                    }
                } else if member == userId {
                    owedByUser[expense.paidBy, default: 0.0] += splitAmount
                }
            }

        case .shares:
            let totalShares = expense.splitData?.values.reduce(0, +) ?? 0
            for (member, shares) in expense.splitData ?? [:] {
                let splitAmount = expense.amount * (Double(shares) / Double(totalShares))
                if expense.paidBy == userId {
                    if member != userId {
                        owesToUser[member, default: 0.0] += splitAmount
                    }
                } else if member == userId {
                    owedByUser[expense.paidBy, default: 0.0] += splitAmount
                }
            }
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
        let splitAmount = expense.amount / Double(expense.splitTo.count)

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

    var mutableUsers = users
    var debts: [(String, String, Double)] = []

    // Separate users into creditors and debtors
    let positiveAmounts = mutableUsers.filter { $0.value > 0 }
    let negativeAmounts = mutableUsers.filter { $0.value < 0 }

    // Settle debts by matching creditors and debtors
    for (creditor, creditAmount) in positiveAmounts {
        var remainingCredit = creditAmount

        for (debtor, debtAmount) in negativeAmounts {
            if remainingCredit == 0 { break }
            let amountToSettle = min(remainingCredit, -debtAmount)

            if amountToSettle > 0 {
                debts.append((debtor, creditor, amountToSettle))
                remainingCredit -= amountToSettle
                mutableUsers[debtor]! += amountToSettle
                mutableUsers[creditor]! -= amountToSettle
            }
        }
    }

    return debts
}

// Used in settings and totals screen's total change in balance calculation
public func calculateTransactionsWithExpenses(expenses: [Expense], transactions: [Transactions]) -> [String: Double] {
    var amountOweByMember: [String: Double] = [:]

    for expense in expenses {
        amountOweByMember[expense.paidBy, default: 0.0] += expense.amount

        switch expense.splitType {
        case .equally:
            let splitAmount = expense.amount / Double(expense.splitTo.count)
            for member in expense.splitTo {
                amountOweByMember[member, default: 0.0] -= splitAmount
            }
        case .percentage:
            guard let splitData = expense.splitData else { return [:] }
            let totalPercentage = splitData.values.reduce(0, +)
            for (member, percentage) in splitData {
                let splitAmount = (expense.amount * percentage / totalPercentage)
                amountOweByMember[member, default: 0.0] -= splitAmount
            }
        case .shares:
            guard let splitData = expense.splitData else { continue }
            let totalShares = splitData.values.reduce(0, +)
            for (member, shares) in splitData {
                let splitAmount = (expense.amount * Double(shares) / Double(totalShares))
                amountOweByMember[member, default: 0.0] -= splitAmount
            }
        }
    }

    for transaction in transactions {
        amountOweByMember[transaction.payerId, default: 0.0] += transaction.amount
        amountOweByMember[transaction.receiverId, default: 0.0] -= transaction.amount
    }

    return amountOweByMember
}
