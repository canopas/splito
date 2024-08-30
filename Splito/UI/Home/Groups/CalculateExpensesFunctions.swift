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

public enum ExpenseUpdateType {
    case Add
    case Update(oldExpense: Expense)
    case Delete
}

public enum TransactionUpdateType {
    case Add
    case Update(oldTransaction: Transactions)
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

// MARK: - Get Group's Latest Balance with Expense Change

func getLatestSummaryIndex(totalSummary: [GroupTotalSummary], date: Date) -> Int? {
    let year = Calendar.current.component(.year, from: date)
    let month = Calendar.current.component(.month, from: date)
    return totalSummary.firstIndex(where: { $0.month == month && $0.year == year })
}

func getLatestSummaryFrom(totalSummary: [GroupTotalSummary], date: Date) -> GroupTotalSummary? {
    let year = Calendar.current.component(.year, from: date)
    let month = Calendar.current.component(.month, from: date)
    return totalSummary.first(where: { $0.month == month && $0.year == year })
}

public func getUpdatedMemberBalanceFor(expense: Expense, group: Groups, updateType: ExpenseUpdateType) -> [GroupMemberBalance] {
    var memberBalance = group.balances
    let expenseDate = expense.date.dateValue()

    for member in group.members {
        let newSplitAmount = getCalculatedSplitAmount(member: member, expense: expense)
        if let index = memberBalance.firstIndex(where: { $0.id == member }) {
            switch updateType {
            case .Add:
                memberBalance[index].balance += newSplitAmount

                if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[index].totalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending += expense.amount
                    totalSummary.totalPaidAmount += expense.paidBy[member] ?? 0
                    totalSummary.totalShare += newSplitAmount
                    totalSummary.changeInBalance = totalSummary.totalPaidAmount - totalSummary.totalShare

                    memberBalance[index].totalSummary[summaryIndex].summary = totalSummary
                } else {
                    let summary = getInitialGroupSummaryFor(member: member, expense: expense)
                    memberBalance[index].totalSummary.append(summary)
                }

            case .Update(let oldExpense):
                let oldSplitAmount = getCalculatedSplitAmount(member: member, expense: oldExpense)
                memberBalance[index].balance += newSplitAmount - oldSplitAmount

                if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[index].totalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending += expense.amount - oldExpense.amount
                    totalSummary.totalPaidAmount += (expense.paidBy[member] ?? 0) - (oldExpense.paidBy[member] ?? 0)
                    totalSummary.totalShare += newSplitAmount - oldSplitAmount
                    totalSummary.changeInBalance = totalSummary.totalPaidAmount - totalSummary.totalShare

                    memberBalance[index].totalSummary[summaryIndex].summary = totalSummary
                }

            case .Delete:
                memberBalance[index].balance -= newSplitAmount

                if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[index].totalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending -= expense.amount
                    totalSummary.totalPaidAmount -= expense.paidBy[member] ?? 0
                    totalSummary.totalShare -= newSplitAmount
                    totalSummary.changeInBalance = totalSummary.totalPaidAmount - totalSummary.totalShare

                    memberBalance[index].totalSummary[summaryIndex].summary = totalSummary
                }
            }
        } else {
            let summary = getInitialGroupSummaryFor(member: member, expense: expense)
            memberBalance.append(GroupMemberBalance(id: member, balance: newSplitAmount, totalSummary: [summary]))
        }
    }

    return memberBalance
}

func getInitialGroupSummaryFor(member: String, expense: Expense) -> GroupTotalSummary {
    let expenseDate = expense.date.dateValue()
    let expenseYear = Calendar.current.component(.year, from: expenseDate)
    let expenseMonth = Calendar.current.component(.month, from: expenseDate)

    let splitAmount = getCalculatedSplitAmount(member: member, expense: expense)

    let memberSummary = GroupMemberSummary(groupTotalSpending: expense.amount,
                                           totalPaidAmount: expense.paidBy[member] ?? 0,
                                           totalShare: splitAmount, paidAmount: 0, receivedAmount: 0,
                                           changeInBalance: abs((expense.paidBy[member] ?? 0) - splitAmount))
    let totalSummary = GroupTotalSummary(year: expenseYear, month: expenseMonth, summary: memberSummary)
    return totalSummary
}

// MARK: - Get Group's Latest Balance with Transaction Change

public func getUpdatedMemberBalanceFor(transaction: Transactions, group: Groups, updateType: TransactionUpdateType) -> [GroupMemberBalance] {
    var memberBalance = group.balances
    let transactionDate = transaction.date.dateValue()

    let amount = transaction.amount
    let payerId = transaction.payerId
    let receiverId = transaction.receiverId

    let currentYear = Calendar.current.component(.year, from: transactionDate)
    let currentMonth = Calendar.current.component(.month, from: transactionDate)

    // For payer
    if let payerIndex = memberBalance.firstIndex(where: { $0.id == payerId }) {
        switch updateType {
        case .Add:
            memberBalance[payerIndex].balance += amount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate) {
                totalSummary.paidAmount += amount
                totalSummary.changeInBalance = (totalSummary.totalShare + totalSummary.paidAmount) - totalSummary.receivedAmount
                memberBalance[payerIndex].totalSummary[summaryIndex].summary = totalSummary
            } else {
                let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                       totalShare: 0, paidAmount: amount, receivedAmount: 0,
                                                       changeInBalance: memberBalance[payerIndex].balance)
                let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
                memberBalance[payerIndex].totalSummary.append(totalSummary)
            }

        case .Update(let oldTransaction):
            let oldAmount = oldTransaction.amount
            memberBalance[payerIndex].balance += amount - oldAmount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate) {
                totalSummary.paidAmount += amount - oldAmount
                totalSummary.changeInBalance = (totalSummary.totalShare + totalSummary.paidAmount) - totalSummary.receivedAmount
                memberBalance[payerIndex].totalSummary[summaryIndex].summary = totalSummary
            }

        case .Delete:
            memberBalance[payerIndex].balance -= amount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate) {
                totalSummary.paidAmount -= amount
                totalSummary.changeInBalance = (totalSummary.totalShare + totalSummary.paidAmount) - totalSummary.receivedAmount
                memberBalance[payerIndex].totalSummary[summaryIndex].summary = totalSummary
            }
        }
    } else {
        let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0, totalShare: 0,
                                               paidAmount: amount, receivedAmount: 0, changeInBalance: amount)
        let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
        memberBalance.append(GroupMemberBalance(id: payerId, balance: amount, totalSummary: [totalSummary]))
    }

    // For receiver
    if let receiverIndex = memberBalance.firstIndex(where: { $0.id == receiverId }) {
        switch updateType {
        case .Add:
            memberBalance[receiverIndex].balance -= amount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate) {
                totalSummary.receivedAmount += amount
                totalSummary.changeInBalance = (totalSummary.totalShare - totalSummary.receivedAmount) + totalSummary.paidAmount
                memberBalance[receiverIndex].totalSummary[summaryIndex].summary = totalSummary
            } else {
                let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                       totalShare: 0, paidAmount: 0, receivedAmount: amount,
                                                       changeInBalance: memberBalance[receiverIndex].balance)
                let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
                memberBalance[receiverIndex].totalSummary.append(totalSummary)
            }

        case .Update(let oldTransaction):
            let oldAmount = oldTransaction.amount
            memberBalance[receiverIndex].balance -= amount - oldAmount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate) {
                totalSummary.receivedAmount += amount - oldAmount
                totalSummary.changeInBalance = (totalSummary.totalShare - totalSummary.receivedAmount) + totalSummary.paidAmount
                memberBalance[receiverIndex].totalSummary[summaryIndex].summary = totalSummary
            }

        case .Delete:
            memberBalance[receiverIndex].balance += amount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate) {
                totalSummary.receivedAmount -= amount
                totalSummary.changeInBalance = (totalSummary.totalShare - totalSummary.receivedAmount) + totalSummary.paidAmount
                memberBalance[receiverIndex].totalSummary[summaryIndex].summary = totalSummary
            }
        }
    } else {
        let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0, totalShare: 0,
                                               paidAmount: 0, receivedAmount: amount, changeInBalance: -amount)
        let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
        memberBalance.append(GroupMemberBalance(id: receiverId, balance: -amount, totalSummary: [totalSummary]))
    }

    let epsilon = 1e-10
    for i in 0..<memberBalance.count where abs(memberBalance[i].balance) < epsilon {
        memberBalance[i].balance = 0
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
