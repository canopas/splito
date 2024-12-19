//
//  CalculateExpensesFunctions.swift
//  Splito
//
//  Created by Amisha Italiya on 24/06/24.
//

import Data
import UIKit

// MARK: - Simplified expense calculation

/// Store settlement amount with the persons
public struct Settlement {
    let sender: String
    let receiver: String
    let amount: Double
}

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

/// To decide who owes -> how much amount -> to whom
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

/// Get Group's Latest Balance with Expense Change
public func getUpdatedMemberBalanceFor(expense: Expense, group: Groups, updateType: ExpenseUpdateType) -> [GroupMemberBalance] {
    var memberBalance = group.balances
    let expenseDate = expense.date.dateValue()

    for member in group.members {
        let newSplitAmount = expense.getCalculatedSplitAmountOf(member: member)
        let totalSplitAmount = expense.getTotalSplitAmountOf(member: member)

        // Check if the member already has an entry in the member balance array
        if let index = memberBalance.firstIndex(where: { $0.id == member }) {
            switch updateType {
            case .Add:
                memberBalance[index].balance += newSplitAmount

                // Update the corresponding total summary if it exists for the expense date
                if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[index].totalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending += expense.amount
                    totalSummary.totalPaidAmount += (expense.paidBy[member] ?? 0)
                    totalSummary.totalShare += totalSplitAmount
                    totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare) - totalSummary.receivedAmount + totalSummary.paidAmount

                    memberBalance[index].totalSummary[summaryIndex].summary = totalSummary
                } else {
                    // If no summary exists for the date, create a new summary
                    let summary = getInitialGroupSummaryFor(member: member, expense: expense)
                    memberBalance[index].totalSummary.append(summary)
                }

            case .Update(let oldExpense):
                let oldSplitAmount = oldExpense.getTotalSplitAmountOf(member: member)

                // Update the old date's summary by reversing the old expense values
                if let oldSummaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary,
                                                               date: oldExpense.date.dateValue()) {
                    var oldSummary = memberBalance[index].totalSummary[oldSummaryIndex].summary
                    oldSummary.groupTotalSpending -= oldExpense.amount
                    oldSummary.totalPaidAmount -= (oldExpense.paidBy[member] ?? 0)
                    oldSummary.totalShare -= abs(oldSplitAmount)
                    oldSummary.changeInBalance = (oldSummary.totalPaidAmount - oldSummary.totalShare) - oldSummary.receivedAmount + oldSummary.paidAmount

                    memberBalance[index].totalSummary[oldSummaryIndex].summary = oldSummary
                }

                let oldCalculatedSplitAmount = oldExpense.getCalculatedSplitAmountOf(member: member)
                memberBalance[index].balance += (newSplitAmount - oldCalculatedSplitAmount)

                // Update the new date's summary
                if var newSummary = getLatestSummaryFrom(totalSummary: memberBalance[index].totalSummary, date: expenseDate)?.summary,
                   let newSummaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary, date: expenseDate) {
                    newSummary.groupTotalSpending += expense.amount
                    newSummary.totalPaidAmount += (expense.paidBy[member] ?? 0)
                    newSummary.totalShare += totalSplitAmount
                    newSummary.changeInBalance = (newSummary.totalPaidAmount - newSummary.totalShare) - newSummary.receivedAmount + newSummary.paidAmount

                    memberBalance[index].totalSummary[newSummaryIndex].summary = newSummary
                } else {
                    let summary = getInitialGroupSummaryFor(member: member, expense: expense)
                    memberBalance[index].totalSummary.append(summary)
                }

            case .Delete:
                memberBalance[index].balance -= newSplitAmount

                if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[index].totalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[index].totalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending -= expense.amount
                    totalSummary.totalPaidAmount -= (expense.paidBy[member] ?? 0)
                    totalSummary.totalShare -= totalSplitAmount
                    totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare) - totalSummary.receivedAmount + totalSummary.paidAmount

                    memberBalance[index].totalSummary[summaryIndex].summary = totalSummary
                }
            }
        } else {
            // If the member doesn't have an existing entry, create a new one with the initial balance and summary
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

    let splitAmount = abs(expense.getTotalSplitAmountOf(member: member))

    let memberSummary = GroupMemberSummary(groupTotalSpending: expense.amount,
                                           totalPaidAmount: expense.paidBy[member] ?? 0,
                                           totalShare: splitAmount, paidAmount: 0, receivedAmount: 0,
                                           changeInBalance: (expense.paidBy[member] ?? 0.0) - splitAmount)

    let totalSummary = GroupTotalSummary(year: expenseYear, month: expenseMonth, summary: memberSummary)
    return totalSummary
}

// MARK: - Get Group's Latest Balance with Transaction Change

/// Get Group's Latest Balance with Transaction Change
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

            // Check if there's an existing summary for this date
            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate) {
                totalSummary.paidAmount += amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare) - totalSummary.receivedAmount + totalSummary.paidAmount
                memberBalance[payerIndex].totalSummary[summaryIndex].summary = totalSummary
            } else {
                // If no summary exists, create a new one
                let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                       totalShare: 0, paidAmount: amount, receivedAmount: 0,
                                                       changeInBalance: amount)
                let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
                memberBalance[payerIndex].totalSummary.append(totalSummary)
            }

        case .Update(let oldTransaction):
            let oldAmount = oldTransaction.amount
            let oldTransactionDate = oldTransaction.date.dateValue()

            // Update the summary for the old transaction date
            if let oldSummaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: oldTransactionDate) {
                var oldSummary = memberBalance[payerIndex].totalSummary[oldSummaryIndex].summary
                oldSummary.paidAmount -= oldAmount
                oldSummary.changeInBalance = (oldSummary.totalPaidAmount - oldSummary.totalShare) - oldSummary.receivedAmount + oldSummary.paidAmount
                memberBalance[payerIndex].totalSummary[oldSummaryIndex].summary = oldSummary
            }

            memberBalance[payerIndex].balance += (amount - oldAmount)

            // Update the summary for the new transaction date
            if var newSummary = getLatestSummaryFrom(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate)?.summary,
               let newSummaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate) {
                newSummary.paidAmount += amount
                newSummary.changeInBalance = (newSummary.totalPaidAmount - newSummary.totalShare) - newSummary.receivedAmount + newSummary.paidAmount
                memberBalance[payerIndex].totalSummary[newSummaryIndex].summary = newSummary
            } else {
                // If no summary exists for the new date, create a new one
                let newMemberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                          totalShare: 0, paidAmount: amount, receivedAmount: 0,
                                                          changeInBalance: amount)
                let newTotalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: newMemberSummary)
                memberBalance[payerIndex].totalSummary.append(newTotalSummary)
            }

        case .Delete:
            memberBalance[payerIndex].balance -= amount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[payerIndex].totalSummary, date: transactionDate) {
                totalSummary.paidAmount -= amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare - totalSummary.receivedAmount + totalSummary.paidAmount)
                memberBalance[payerIndex].totalSummary[summaryIndex].summary = totalSummary
            }
        }
    } else {
        // If the payer does not have an existing balance entry, create a new one
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

            // Check if there's an existing summary for this date
            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate) {
                totalSummary.receivedAmount += amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare - totalSummary.receivedAmount + totalSummary.paidAmount)
                memberBalance[receiverIndex].totalSummary[summaryIndex].summary = totalSummary
            } else {
                // If no summary exists, create a new one
                let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                       totalShare: 0, paidAmount: 0, receivedAmount: amount,
                                                       changeInBalance: -amount)
                let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
                memberBalance[receiverIndex].totalSummary.append(totalSummary)
            }

        case .Update(let oldTransaction):
            let oldAmount = oldTransaction.amount
            let oldTransactionDate = oldTransaction.date.dateValue()

            // Update the summary for the old transaction date
            if let oldSummaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: oldTransactionDate) {
                var oldSummary = memberBalance[receiverIndex].totalSummary[oldSummaryIndex].summary
                oldSummary.receivedAmount -= oldAmount
                oldSummary.changeInBalance = (oldSummary.totalPaidAmount - oldSummary.totalShare - oldSummary.receivedAmount + oldSummary.paidAmount)
                memberBalance[receiverIndex].totalSummary[oldSummaryIndex].summary = oldSummary
            }

            memberBalance[receiverIndex].balance -= (amount - oldAmount)

            // Update the summary for the new transaction date
            if var newSummary = getLatestSummaryFrom(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate)?.summary,
               let newSummaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate) {
                newSummary.receivedAmount += amount
                newSummary.changeInBalance = (newSummary.totalPaidAmount - newSummary.totalShare - newSummary.receivedAmount + newSummary.paidAmount)
                memberBalance[receiverIndex].totalSummary[newSummaryIndex].summary = newSummary
            } else {
                // If no summary exists for the new date, create a new one
                let newMemberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                          totalShare: 0, paidAmount: 0, receivedAmount: amount,
                                                          changeInBalance: -amount)
                let newTotalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: newMemberSummary)
                memberBalance[receiverIndex].totalSummary.append(newTotalSummary)
            }

        case .Delete:
            memberBalance[receiverIndex].balance += amount

            if var totalSummary = getLatestSummaryFrom(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: memberBalance[receiverIndex].totalSummary, date: transactionDate) {
                totalSummary.receivedAmount -= amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare - totalSummary.receivedAmount + totalSummary.paidAmount)
                memberBalance[receiverIndex].totalSummary[summaryIndex].summary = totalSummary
            }
        }
    } else {
        // If the receiver does not have an existing balance entry, create a new one
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

// Filtered group total summary data for current month
public func getTotalSummaryForCurrentMonth(group: Groups?, userId: String?) -> [GroupTotalSummary] {
    guard let userId, let group else { return [] }

    let currentMonth = Calendar.current.component(.month, from: Date())
    let currentYear = Calendar.current.component(.year, from: Date())

    return group.balances.first(where: { $0.id == userId })?.totalSummary.filter {
        $0.month == currentMonth && $0.year == currentYear
    } ?? []
}
