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
    let currency: String
}

public func calculateExpensesSimplified(userId: String,
                                        memberBalances: [GroupMemberBalance]) -> [String: [String: Double]] {
    var memberOwingAmount: [String: [String: Double]] = [:]

    // Calculate settlements based on balances
    let settlements = calculateSettlements(balances: memberBalances)

    // Loop over each settlement to calculate owed amounts
    for settlement in settlements where settlement.sender == userId || settlement.receiver == userId {
        let memberId = settlement.receiver == userId ? settlement.sender : settlement.receiver
        let amount = settlement.sender == userId ? -settlement.amount : settlement.amount

        // Add the calculated amount to the corresponding currency and member
        memberOwingAmount[settlement.currency, default: [:]][memberId, default: 0] += amount
    }

    // Remove entries where the amount is zero for all currencies
    memberOwingAmount = memberOwingAmount.mapValues { currencyAmounts in
        currencyAmounts.filter { $0.value != 0 }
    }

    return memberOwingAmount
}

/// Helper function to extract all currencies from the balances
private func extractAllCurrencies(from balances: [GroupMemberBalance]) -> [String] {
    var currencies: Set<String> = []
    for balance in balances {
        currencies.formUnion(balance.balanceByCurrency.keys)
    }
    return Array(currencies)
}

/// To decide who owes -> how much amount -> to whom
func calculateSettlements(balances: [GroupMemberBalance]) -> [Settlement] {
    var settlements: [Settlement] = []

    for currency in extractAllCurrencies(from: balances) {
        var creditors: [(String, Double)] = []
        var debtors: [(String, Double)] = []

        // Separate creditors and debtors for the current currency
        for balance in balances {
            if let currencyBalance = balance.balanceByCurrency[currency]?.balance {
                if currencyBalance > 0 {
                    creditors.append((balance.id, currencyBalance))
                } else if currencyBalance < 0 {
                    debtors.append((balance.id, -currencyBalance)) // Store positive value for easier calculation
                }
            }
        }

        // Sort creditors and debtors by the amount they owe or are owed
        creditors.sort { $0.1 < $1.1 }
        debtors.sort { $0.1 < $1.1 }

        var i = 0 // creditors index
        var j = 0 // debtors index

        // Calculate settlements for the current currency
        while i < creditors.count && j < debtors.count {
            var (creditor, credAmt) = creditors[i]
            var (debtor, debtAmt) = debtors[j]
            let minAmount = min(credAmt, debtAmt)

            settlements.append(Settlement(sender: debtor, receiver: creditor, amount: minAmount, currency: currency))

            // Update the amounts
            credAmt -= minAmount
            debtAmt -= minAmount

            // If the remaining amount is close to zero, treat it as zero
            creditors[i].1 = round(credAmt * 100) / 100
            debtors[j].1 = round(debtAmt * 100) / 100

            // Move the index forward if someone's balance is settled
            let epsilon = 1e-10
            if abs(creditors[i].1) < epsilon { i += 1 }
            if abs(debtors[j].1) < epsilon { j += 1 }
        }
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
    let currency = expense.currencyCode ?? Currency.defaultCurrency.code

    for member in group.members {
        let newSplitAmount = expense.getCalculatedSplitAmountOf(member: member)
        let totalSplitAmount = expense.getTotalSplitAmountOf(member: member)

        // Check if the member already has an entry in the member balance array
        if let index = memberBalance.firstIndex(where: { $0.id == member }) {
            if memberBalance[index].balanceByCurrency[currency] == nil {
                memberBalance[index].balanceByCurrency[currency] = GroupCurrencyBalance(balance: 0.0, totalSummary: [])
            }

            switch updateType {
            case .Add:
                memberBalance[index].balanceByCurrency[currency]?.balance += newSplitAmount

                // Update the corresponding total summary if it exists for the expense date
                let groupTotalSummary = memberBalance[index].balanceByCurrency[currency]?.totalSummary ?? []
                if var totalSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending += expense.amount
                    totalSummary.totalPaidAmount += (expense.paidBy[member] ?? 0)
                    totalSummary.totalShare += totalSplitAmount
                    totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare) - totalSummary.receivedAmount + totalSummary.paidAmount

                    memberBalance[index].balanceByCurrency[currency]?.totalSummary[summaryIndex].summary = totalSummary
                } else {
                    // If no summary exists for the date, create a new summary
                    let summary = getInitialGroupSummaryFor(member: member, expense: expense)
                    memberBalance[index].balanceByCurrency[currency]?.totalSummary.append(summary)
                }

            case .Update(let oldExpense):
                let oldSplitAmount = oldExpense.getCalculatedSplitAmountOf(member: member)
                let oldTotalSplitAmount = oldExpense.getTotalSplitAmountOf(member: member)
                let oldCurrency = oldExpense.currencyCode ?? Currency.defaultCurrency.code

                memberBalance[index].balanceByCurrency[oldCurrency]?.balance -= oldSplitAmount

                // Update the old date's summary by reversing the old expense values
                let groupOldTotalSummary = memberBalance[index].balanceByCurrency[oldCurrency]?.totalSummary ?? []
                if let oldSummaryIndex = getLatestSummaryIndex(totalSummary: groupOldTotalSummary,
                                                               date: oldExpense.date.dateValue()) {
                    var oldSummary = groupOldTotalSummary[oldSummaryIndex].summary
                    oldSummary.groupTotalSpending -= oldExpense.amount
                    oldSummary.totalPaidAmount -= (oldExpense.paidBy[member] ?? 0)
                    oldSummary.totalShare -= abs(oldTotalSplitAmount)
                    oldSummary.changeInBalance = (oldSummary.totalPaidAmount - oldSummary.totalShare) - oldSummary.receivedAmount + oldSummary.paidAmount
                    memberBalance[index].balanceByCurrency[oldCurrency]?.totalSummary[oldSummaryIndex].summary = oldSummary
                }

                memberBalance[index].balanceByCurrency[currency]?.balance += newSplitAmount

                // Update the new date's summary
                let groupNewTotalSummary = memberBalance[index].balanceByCurrency[currency]?.totalSummary ?? []
                if var newSummary = getLatestSummaryFrom(totalSummary: groupNewTotalSummary, date: expenseDate)?.summary,
                   let newSummaryIndex = getLatestSummaryIndex(totalSummary: groupNewTotalSummary, date: expenseDate) {
                    newSummary.groupTotalSpending += expense.amount
                    newSummary.totalPaidAmount += (expense.paidBy[member] ?? 0)
                    newSummary.totalShare += totalSplitAmount
                    newSummary.changeInBalance = (newSummary.totalPaidAmount - newSummary.totalShare) - newSummary.receivedAmount + newSummary.paidAmount

                    memberBalance[index].balanceByCurrency[currency]?.totalSummary[newSummaryIndex].summary = newSummary
                } else {
                    let summary = getInitialGroupSummaryFor(member: member, expense: expense)
                    memberBalance[index].balanceByCurrency[currency]?.totalSummary.append(summary)
                }

            case .Delete:
                memberBalance[index].balanceByCurrency[currency]?.balance -= newSplitAmount

                let groupTotalSummary = memberBalance[index].balanceByCurrency[currency]?.totalSummary ?? []
                if var totalSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: expenseDate)?.summary,
                   let summaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: expenseDate) {
                    totalSummary.groupTotalSpending -= expense.amount
                    totalSummary.totalPaidAmount -= (expense.paidBy[member] ?? 0)
                    totalSummary.totalShare -= totalSplitAmount
                    totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare) - totalSummary.receivedAmount + totalSummary.paidAmount

                    memberBalance[index].balanceByCurrency[currency]?.totalSummary[summaryIndex].summary = totalSummary
                }
            }
        } else {
            // If the member doesn't have an existing entry, create a new one with the initial balance and summary
            let summary = getInitialGroupSummaryFor(member: member, expense: expense)
            memberBalance.append(
                GroupMemberBalance(id: member,
                                   balanceByCurrency: [currency:
                                                        GroupCurrencyBalance(balance: newSplitAmount,
                                                                             totalSummary: [summary])
                                                      ])
            )
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
    let currency = transaction.currencyCode ?? Currency.defaultCurrency.code

    let currentYear = Calendar.current.component(.year, from: transactionDate)
    let currentMonth = Calendar.current.component(.month, from: transactionDate)

    // For payer
    if let payerIndex = memberBalance.firstIndex(where: { $0.id == payerId }) {
        if memberBalance[payerIndex].balanceByCurrency[currency] == nil {
            memberBalance[payerIndex].balanceByCurrency[currency] = GroupCurrencyBalance(balance: 0.0, totalSummary: [])
        }

        switch updateType {
        case .Add:
            memberBalance[payerIndex].balanceByCurrency[currency]?.balance += amount

            // Check if there's an existing summary for this date
            let groupTotalSummary = memberBalance[payerIndex].balanceByCurrency[currency]?.totalSummary ?? []
            if var totalSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: transactionDate) {
                totalSummary.paidAmount += amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare) - totalSummary.receivedAmount + totalSummary.paidAmount
                memberBalance[payerIndex].balanceByCurrency[currency]?.totalSummary[summaryIndex].summary = totalSummary
            } else {
                // If no summary exists, create a new one
                let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                       totalShare: 0, paidAmount: amount, receivedAmount: 0,
                                                       changeInBalance: amount)
                let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
                memberBalance[payerIndex].balanceByCurrency[currency]?.totalSummary.append(totalSummary)
            }

        case .Update(let oldTransaction):
            let oldAmount = oldTransaction.amount
            let oldTransactionDate = oldTransaction.date.dateValue()
            let oldPayerId = oldTransaction.payerId
            let oldCurrency = oldTransaction.currencyCode ?? Currency.defaultCurrency.code

            // Handle payer role switch: Update the old payer's balance and summary
            if let oldPayerIndex = memberBalance.firstIndex(where: { $0.id == oldPayerId }) {
                memberBalance[oldPayerIndex].balanceByCurrency[oldCurrency]?.balance -= oldAmount
                let groupTotalSummary = memberBalance[oldPayerIndex].balanceByCurrency[oldCurrency]?.totalSummary ?? []
                if let oldSummaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: oldTransactionDate) {
                    var oldSummary = groupTotalSummary[oldSummaryIndex].summary
                    oldSummary.paidAmount -= oldAmount
                    oldSummary.changeInBalance = (oldSummary.totalPaidAmount - oldSummary.totalShare) - oldSummary.receivedAmount + oldSummary.paidAmount
                    memberBalance[oldPayerIndex].balanceByCurrency[oldCurrency]?.totalSummary[oldSummaryIndex].summary = oldSummary
                }
            }

            // Update new payer's balance and summary for the new transaction with switched roles
            if let newPayerIndex = memberBalance.firstIndex(where: { $0.id == payerId }) {
                memberBalance[newPayerIndex].balanceByCurrency[currency]?.balance += amount
                let groupTotalSummary = memberBalance[newPayerIndex].balanceByCurrency[currency]?.totalSummary ?? []
                if var newSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: transactionDate)?.summary,
                   let newSummaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: transactionDate) {
                    newSummary.paidAmount += amount
                    newSummary.changeInBalance = (newSummary.totalPaidAmount - newSummary.totalShare) - newSummary.receivedAmount + newSummary.paidAmount
                    memberBalance[newPayerIndex].balanceByCurrency[currency]?.totalSummary[newSummaryIndex].summary = newSummary
                } else {
                    // If no summary exists for the new date, create a new one
                    let newMemberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                              totalShare: 0, paidAmount: amount, receivedAmount: 0,
                                                              changeInBalance: amount)
                    let newTotalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: newMemberSummary)
                    memberBalance[newPayerIndex].balanceByCurrency[currency]?.totalSummary.append(newTotalSummary)
                }
            }

        case .Delete:
            memberBalance[payerIndex].balanceByCurrency[currency]?.balance -= amount

            let groupTotalSummary = memberBalance[payerIndex].balanceByCurrency[currency]?.totalSummary ?? []
            if var totalSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: transactionDate) {
                totalSummary.paidAmount -= amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare - totalSummary.receivedAmount + totalSummary.paidAmount)
                memberBalance[payerIndex].balanceByCurrency[currency]?.totalSummary[summaryIndex].summary = totalSummary
            }
        }
    } else {
        // If the payer does not have an existing balance entry, create a new one
        let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0, totalShare: 0,
                                               paidAmount: amount, receivedAmount: 0, changeInBalance: amount)
        let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
        memberBalance.append(GroupMemberBalance(id: payerId,
                                                balanceByCurrency: [
                                                    currency: GroupCurrencyBalance(balance: amount,
                                                                                    totalSummary: [totalSummary])
                                                ]))
    }

    // For receiver
    if let receiverIndex = memberBalance.firstIndex(where: { $0.id == receiverId }) {
        if memberBalance[receiverIndex].balanceByCurrency[currency] == nil {
            memberBalance[receiverIndex].balanceByCurrency[currency] = GroupCurrencyBalance(balance: 0.0, totalSummary: [])
        }

        switch updateType {
        case .Add:
            memberBalance[receiverIndex].balanceByCurrency[currency]?.balance -= amount

            // Check if there's an existing summary for this date
            let groupTotalSummary = memberBalance[receiverIndex].balanceByCurrency[currency]?.totalSummary ?? []
            if var totalSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: transactionDate) {
                totalSummary.receivedAmount += amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare - totalSummary.receivedAmount + totalSummary.paidAmount)
                memberBalance[receiverIndex].balanceByCurrency[currency]?.totalSummary[summaryIndex].summary = totalSummary
            } else {
                // If no summary exists, create a new one
                let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                       totalShare: 0, paidAmount: 0, receivedAmount: amount,
                                                       changeInBalance: -amount)
                let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
                memberBalance[receiverIndex].balanceByCurrency[currency]?.totalSummary.append(totalSummary)
            }

        case .Update(let oldTransaction):
            let oldAmount = oldTransaction.amount
            let oldTransactionDate = oldTransaction.date.dateValue()
            let oldReceiverId = oldTransaction.receiverId
            let oldCurrency = oldTransaction.currencyCode ?? Currency.defaultCurrency.code

            // Handle receiver role switch: Update the old receiver's balance and summary
            if let oldReceiverIndex = memberBalance.firstIndex(where: { $0.id == oldReceiverId }) {
                memberBalance[oldReceiverIndex].balanceByCurrency[oldCurrency]?.balance += oldAmount
                let groupTotalSummary = memberBalance[oldReceiverIndex].balanceByCurrency[oldCurrency]?.totalSummary ?? []
                if let oldSummaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: oldTransactionDate) {
                    var oldSummary = groupTotalSummary[oldSummaryIndex].summary
                    oldSummary.receivedAmount -= oldAmount
                    oldSummary.changeInBalance = (oldSummary.totalPaidAmount - oldSummary.totalShare) - oldSummary.receivedAmount + oldSummary.paidAmount
                    memberBalance[oldReceiverIndex].balanceByCurrency[oldCurrency]?.totalSummary[oldSummaryIndex].summary = oldSummary
                }
            }

            // Update new receiver's balance and summary for the new transaction with switched roles
            if let newReceiverIndex = memberBalance.firstIndex(where: { $0.id == receiverId }) {
                memberBalance[newReceiverIndex].balanceByCurrency[currency]?.balance -= amount
                let groupTotalSummary = memberBalance[newReceiverIndex].balanceByCurrency[currency]?.totalSummary ?? []
                if var newSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: transactionDate)?.summary,
                   let newSummaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: transactionDate) {
                    newSummary.receivedAmount += amount
                    newSummary.changeInBalance = (newSummary.totalPaidAmount - newSummary.totalShare) - newSummary.receivedAmount + newSummary.paidAmount
                    memberBalance[newReceiverIndex].balanceByCurrency[currency]?.totalSummary[newSummaryIndex].summary = newSummary
                } else {
                    // If no summary exists for the new date, create a new one
                    let newMemberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0,
                                                              totalShare: 0, paidAmount: 0, receivedAmount: amount,
                                                              changeInBalance: -amount)
                    let newTotalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: newMemberSummary)
                    memberBalance[newReceiverIndex].balanceByCurrency[currency]?.totalSummary.append(newTotalSummary)
                }
            }

        case .Delete:
            memberBalance[receiverIndex].balanceByCurrency[currency]?.balance += amount

            let groupTotalSummary = memberBalance[receiverIndex].balanceByCurrency[currency]?.totalSummary ?? []
            if var totalSummary = getLatestSummaryFrom(totalSummary: groupTotalSummary, date: transactionDate)?.summary,
               let summaryIndex = getLatestSummaryIndex(totalSummary: groupTotalSummary, date: transactionDate) {
                totalSummary.receivedAmount -= amount
                totalSummary.changeInBalance = (totalSummary.totalPaidAmount - totalSummary.totalShare - totalSummary.receivedAmount + totalSummary.paidAmount)
                memberBalance[receiverIndex].balanceByCurrency[currency]?.totalSummary[summaryIndex].summary = totalSummary
            }
        }
    } else {
        // If the receiver does not have an existing balance entry, create a new one
        let memberSummary = GroupMemberSummary(groupTotalSpending: 0, totalPaidAmount: 0, totalShare: 0,
                                               paidAmount: 0, receivedAmount: amount, changeInBalance: -amount)
        let totalSummary = GroupTotalSummary(year: currentYear, month: currentMonth, summary: memberSummary)
        memberBalance.append(GroupMemberBalance(id: receiverId,
                                                balanceByCurrency: [
                                                    currency: GroupCurrencyBalance(balance: -amount,
                                                                                    totalSummary: [totalSummary])
                                                ]))
    }

    let epsilon = 1e-10
    for i in 0..<memberBalance.count where abs(memberBalance[i].balanceByCurrency[currency]?.balance ?? 0) < epsilon {
        memberBalance[i].balanceByCurrency[currency]?.balance = 0
    }

    return memberBalance
}

// Filtered group total summary data for current month
public func getTotalSummaryForCurrentMonth(group: Groups?, userId: String?) -> [String: [GroupTotalSummary]] {
    guard let userId, let group else { return [:] }

    let currentMonth = Calendar.current.component(.month, from: Date())
    let currentYear = Calendar.current.component(.year, from: Date())

    // Find the user's balanceByCurrency data
    guard let balanceByCurrency = group.balances.first(where: { $0.id == userId })?.balanceByCurrency else { return [:] }

    // Iterate through each currency and filter the summary for the current month and year
    var summaryByCurrency: [String: [GroupTotalSummary]] = [:]
    for (currency, groupCurrencyBalance) in balanceByCurrency {
        let filteredSummary = groupCurrencyBalance.totalSummary.filter {
            $0.month == currentMonth && $0.year == currentYear
        }
        summaryByCurrency[currency] = filteredSummary
    }
    return summaryByCurrency
}
