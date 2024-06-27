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

    for expense in expenses {
        let splitAmount = expense.amount / Double(expense.splitTo.count)

        if expense.paidBy == userId {
            // If the user paid for the expense, calculate how much each member owes the user
            for member in expense.splitTo where member != userId {
                owesToUser[member, default: 0.0] += splitAmount
            }
        } else if expense.splitTo.contains(where: { $0 == userId }) {
            // If the user is one of the members who should split the expense, calculate how much the user owes to the payer
            owedByUser[expense.paidBy, default: 0.0] += splitAmount
        }
    }

    let memberOwingAmount = processTransactions(userId: userId, transactions: transactions, owesToUser: owesToUser, owedByUser: owedByUser, isSimplify: false)

    return memberOwingAmount.filter { $0.value != 0 }
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

    memberOwingAmount = processTransactions(userId: userId, transactions: transactions, ownAmounts: memberOwingAmount, isSimplify: true)

    return memberOwingAmount.filter { $0.value != 0 }
}

public func processTransactions(userId: String, transactions: [Transactions], owesToUser: [String: Double]? = nil, owedByUser: [String: Double]? = nil, ownAmounts: [String: Double]? = nil, isSimplify: Bool) -> ([String: Double]) {

    var memberOwingAmount: [String: Double] = isSimplify ? ownAmounts! : [:]

    for transaction in transactions {
        let payer = transaction.payerId
        let receiver = transaction.receiverId
        let amount = transaction.amount

        if isSimplify {
            if payer == userId {
                // If the user is the payer, the receiver owes the user the specified amount
                memberOwingAmount[receiver, default: 0.0] += amount
            } else if receiver == userId {
                // If the user is the receiver, the payer owes the user the specified amount
                memberOwingAmount[payer, default: 0.0] -= amount
            }
        } else {
            var owesToUser = owesToUser!
            var owedByUser = owedByUser!

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

            owesToUser.forEach { payerId, owesAmount in
                memberOwingAmount[payerId, default: 0.0] += owesAmount
            }
            owedByUser.forEach { receiverId, owedAmount in
                memberOwingAmount[receiverId, default: 0.0] -= owedAmount
            }
        }
    }

    return memberOwingAmount
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

public func calculateTransactionsWithExpenses(expenses: [Expense], transactions: [Transactions]) -> [String: Double] {
    var amountOweByMember: [String: Double] = [:]

    for expense in expenses {
        amountOweByMember[expense.paidBy, default: 0.0] += expense.amount

        let splitAmount = expense.amount / Double(expense.splitTo.count)
        for member in expense.splitTo {
            amountOweByMember[member, default: 0.0] -= splitAmount
        }
    }

    for transaction in transactions {
        amountOweByMember[transaction.payerId, default: 0.0] += transaction.amount
        amountOweByMember[transaction.receiverId, default: 0.0] -= transaction.amount
    }

    return amountOweByMember
}
