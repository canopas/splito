//
//  GroupHomeViewModelExtension.swift
//  Splito
//
//  Created by Amisha Italiya on 21/10/24.
//

import Data
import SwiftUI
import BaseStyle
import FirebaseFirestore

// MARK: - User Actions
extension GroupHomeViewModel {
    func getMemberDataBy(id: String) -> AppUser? {
        return groupMembers.first(where: { $0.id == id })
    }

    func handleInviteMemberClick() {
        showInviteMemberSheet = true
    }

    func handleSettingsOptionTap() {
        if groupState == .deactivateGroup || groupState == .memberNotInGroup {
            self.showToastFor(toast: ToastPrompt(type: .info, title: "Whoops!", message: groupState == .deactivateGroup ? "Restore this group to access the settings." : "You're no longer part of this group."))
            return
        }
        router.push(.GroupSettingView(groupId: groupId))
    }

    func handleExpenseItemTap(expenseId: String) {
        router.push(.ExpenseDetailView(groupId: groupId, expenseId: expenseId))
    }

    func handleSettleUpBtnTap() {
        if let group, group.members.count > 1 {
            showSettleUpSheet = true
            onSearchBarCancelBtnTap()
        } else {
            showAlertFor(title: "Whoops!", message: "You're the only member in this group, and there's no point in settling up with yourself :)")
        }
    }

    func manageScrollToTopBtnVisibility(_ value: Bool) {
        showScrollToTopBtn = value
    }

    func handleBalancesBtnTap() {
        showBalancesSheet = true
        onSearchBarCancelBtnTap()
    }

    func handleTotalBtnTap() {
        showGroupTotalSheet = true
        onSearchBarCancelBtnTap()
    }

    func handleTransactionsBtnTap() {
        showTransactionsSheet = true
        onSearchBarCancelBtnTap()
    }

    func handleExportBtnTap() {
        showExportOptions = true
    }

    func handleExportOptionSelection(option: ExportOptions) {
        let startDate = getStartDate(exportOption: option)
        let today = Date()

        exportTask?.cancel()
        exportTask = Task { [weak self] in
            guard let self else { return }
            do {
                let expenses = try await self.expenseRepository.fetchExpenses(groupId: self.groupId, startDate: startDate, endDate: today)
                let transactions = try await self.transactionRepository.fetchTransactions(groupId: self.groupId, startDate: startDate, endDate: today)
                LogD("GroupHomeViewModel: \(#function) Expenses/payments fetched successfully.")

                if expenses.isEmpty && transactions.isEmpty {
                    self.showToastFor(toast: ToastPrompt(type: .info, title: "No Data", message: "No data found for selected time period. Try a different time period."))
                    return
                }

                if let reportURL = await self.generateCSVReport(expenses: expenses, payments: transactions) {
                    groupReportUrl = reportURL
                    showShareReportSheet = true
                } else {
                    showShareReportSheet = false
                    self.showToastFor(toast: ToastPrompt(type: .error, title: "Error",
                                                         message: "Failed to generate group report. Please try again."))
                }
            } catch {
                LogE("GroupHomeViewModel: \(#function) Failed to fetch Expenses/transactions: \(error).")
                self.showToastForError()
            }
        }
    }

    func handleSimplifyInfoSheet() {
        UIApplication.shared.endEditing()
        showSimplifyInfoSheet = true
    }

    func handleSearchOptionTap() {
        if groupState == .deactivateGroup || groupState == .memberNotInGroup {
            self.showToastFor(toast: ToastPrompt(type: .info, title: "Whoops!", message: groupState == .deactivateGroup ? "Restore this group to enable the search functionality." : "You're no longer part of this group."))
            return
        }
        if expenses.isEmpty {
            self.showToastFor(toast: ToastPrompt(type: .info, title: "Whoops!", message: "Add an expense first to use the search functionality."))
            return
        }

        withAnimation {
            searchedExpense = ""
            showSearchBar.toggle()
        }
    }

    func onSearchBarCancelBtnTap() {
        if showSearchBar {
            withAnimation {
                searchedExpense = ""
                showSearchBar = false
            }
        }
    }

    func handleRestoreGroupAction() {
        showAlert = true
        alert = .init(title: "Restore group",
                      message: "This will restore all activities, expenses and payments for this group.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in self?.restoreGroup() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    func restoreGroup() {
        guard var group, let groupId = group.id, let userId = preference.user?.id else { return }

        Task { [weak self] in
            do {
                self?.groupState = .loading
                group.isActive = true
                group.updatedBy = userId

                try await self?.groupRepository.updateGroup(group: group, type: .groupRestored)
                NotificationCenter.default.post(name: .addGroup, object: group)

                self?.fetchGroupAndExpenses()
                LogD("GroupHomeViewModel: \(#function) Group restored successfully.")
            } catch {
                LogE("GroupHomeViewModel: \(#function) Failed to restore group \(groupId): \(error).")
                self?.handleServiceError()
            }
        }
    }

    func showExpenseDeleteAlert(expense: Expense) {
        showAlert = true
        alert = .init(title: "Delete Expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in self?.deleteExpense(expense: expense) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func deleteExpense(expense: Expense) {
        guard let group, let expenseId = expense.id, validateGroupMembers(expense: expense) else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let deletedExpense = try await self.expenseRepository.deleteExpense(group: group, expense: expense)
                NotificationCenter.default.post(name: .deleteExpense, object: deletedExpense)
                await self.updateGroupMemberBalance(expense: deletedExpense, updateType: .Delete)
                LogD("GroupHomeViewModel: \(#function) Expense deleted successfully.")
            } catch {
                LogE("GroupHomeViewModel: \(#function) Failed to delete expense \(expenseId): \(error).")
                self.showToastForError()
            }
        }
    }

    private func validateGroupMembers(expense: Expense) -> Bool {
        guard let group else {
            LogE("GroupHomeViewModel: \(#function) Missing required group.")
            return false
        }

        let missingMemberIds = Set(expense.splitTo + Array(expense.paidBy.keys)).subtracting(group.members)

        if !missingMemberIds.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showAlertFor(message: "This expense involves a person who has left the group, and thus it can no longer be deleted. If you wish to change this expense, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group, let userId = preference.user?.id, let expenseId = expense.id else {
            LogE("GroupHomeViewModel: \(#function) Group or expense information not found.")
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
            group.balances = memberBalance
            group.updatedAt = Timestamp()
            group.updatedBy = userId
            try await groupRepository.updateGroup(group: group, type: .none)
            NotificationCenter.default.post(name: .updateGroup, object: group)
            LogD("GroupHomeViewModel: \(#function) Member balance updated successfully.")
        } catch {
            LogE("GroupHomeViewModel: \(#function) Failed to update member balance for expense \(expenseId): \(error).")
            self.showToastForError()
        }
    }

    func openAddExpenseSheet() {
        showAddExpenseSheet = true
    }

    @objc func handleAddExpense(notification: Notification) {
        guard let expenseInfo = notification.userInfo,
              let newExpense = expenseInfo["expense"] as? Expense,
              let notificationGroupId = expenseInfo["groupId"] as? String,
              notificationGroupId == groupId else { return }

        Task { [weak self] in
            self?.expenses.append(newExpense)
            if let user = await self?.fetchMemberData(for: newExpense.paidBy.keys.first ?? "") {
                let newExpenseWithUser = ExpenseWithUser(expense: newExpense, user: user)
                withAnimation {
                    self?.expensesWithUser.append(newExpenseWithUser)
                    self?.updateGroupExpenses()
                }
            }
        }
    }

    @objc func handleUpdateExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }

        if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
            expenses[index] = updatedExpense
        }

        Task { [weak self] in
            if let user = await self?.fetchMemberData(for: updatedExpense.paidBy.keys.first ?? "") {
                if let index = self?.expensesWithUser.firstIndex(where: { $0.expense.id == updatedExpense.id }) {
                    let updatedExpenseWithUser = ExpenseWithUser(expense: updatedExpense, user: user)
                    withAnimation {
                        self?.expensesWithUser[index] = updatedExpenseWithUser
                        self?.updateGroupExpenses()
                    }
                }
            }
        }
    }

    @objc func handleDeleteExpense(notification: Notification) {
        guard let deletedExpense = notification.object as? Expense else { return }
        expenses.removeAll { $0.id == deletedExpense.id }
        if let index = expensesWithUser.firstIndex(where: { $0.expense.id == deletedExpense.id }) {
            withAnimation {
                expensesWithUser.remove(at: index)
                updateGroupExpenses()
                showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully."))
            }
        }
    }

    @objc func handleAddTransaction(notification: Notification) {
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully."))
        showSettleUpSheet = false
    }

    @objc func handleUpdateGroup(notification: Notification) {
        guard let updatedGroup = notification.object as? Groups else { return }
        group?.name = updatedGroup.name
    }
}

// MARK: - Helper methods for generate report for export
extension GroupHomeViewModel {
    private func getStartDate(exportOption: ExportOptions) -> Date? {
        let today = Date()
        let calendar = Calendar.current

        switch exportOption {
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: today) ?? today
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: today) ?? today
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: today) ?? today
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: today) ?? today
        case .all:
            return nil
        }
    }

    private func generateCSVReport(expenses: [Expense], payments: [Transactions]) async -> URL? {
        guard let group else { return nil }

        // Gather all member IDs from group, expenses & payments
        var allMemberIDs = Set(group.members)
        allMemberIDs.formUnion(expenses.flatMap { $0.participants ?? $0.splitTo + $0.paidBy.keys })
        allMemberIDs.formUnion(payments.flatMap { [$0.payerId, $0.receiverId] })

        // Fetch member names including removed ones
        var memberNames: [String] = []
        for id in allMemberIDs {
            let user = await fetchMemberData(for: id)
            let name = user?.nameWithLastInitial ?? "Unknown"
            memberNames.append(escapeCSV(!group.members.contains(id) ? "\(name) (Removed)" : name))
        }

        var csvContent = ""
        let headers = ["Date", "Description", "Category", "Cost", "Currency"]
            .map(escapeCSV)
            .joined(separator: ",")
        let header = headers + "," + memberNames.joined(separator: ",") + "\n\n"

        csvContent += header
        if !expenses.isEmpty {
            csvContent += createExpensesSection(expenses: expenses, allMemberIDs: allMemberIDs)
        }
        if !payments.isEmpty {
            csvContent += createSettlementsSection(payments: payments, allMemberIDs: allMemberIDs, group: group)
        }
        csvContent += createTotalBalanceSection(group: group, allMemberIDs: allMemberIDs)

        do {
            let filePath = FileManager.default.temporaryDirectory.appendingPathComponent(GROUP_REPORT_FILE_NAME)
            try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try csvContent.write(to: filePath, atomically: true, encoding: .utf8)
            return filePath
        } catch {
            LogE("GroupHomeViewModel: \(#function) Failed to write CSV file: \(error)")
            return nil
        }
    }

    // Helper function to escape CSV text
    private func escapeCSV(_ text: String) -> String {
        // If text contains comma, quote, or newline, wrap in quotes and escape existing quotes
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }

    private func createExpensesSection(expenses: [Expense], allMemberIDs: Set<String>) -> String {
        var section = escapeCSV("Expenses") + "\n"
        for expense in expenses {
            let date = expense.date.dateValue().numericDate
            var row = "\(escapeCSV(date)), \(escapeCSV(expense.name)), \(escapeCSV(expense.category ?? "General")), \(expense.amount), \(escapeCSV(expense.currencyCode ?? "INR"))"

            // Add owe amounts for each member
            for member in allMemberIDs {
                let oweAmount = expense.getCalculatedSplitAmountOf(member: member)
                row += ", \(oweAmount)"
            }
            section += row + "\n"
        }
        return section + "\n"
    }

    private func createSettlementsSection(payments: [Transactions], allMemberIDs: Set<String>, group: Groups) -> String {
        var section = escapeCSV("Settlements") + "\n"
        for payment in payments {
            let date = payment.date.dateValue().numericDate
            let payer = getMemberDataBy(id: payment.payerId)?.nameWithLastInitial ?? "Unknown"
            let receiver = getMemberDataBy(id: payment.receiverId)?.nameWithLastInitial ?? "Unknown"
            let description = "\(escapeCSV(payer)) paid \(escapeCSV(receiver))"
            var row = "\(escapeCSV(date)), \(description), Payment, \(payment.amount), INR"

            // Add paid amount for payer & receiver
            for member in allMemberIDs {
                let amount = member == payment.payerId ? payment.amount : (member == payment.receiverId) ? -payment.amount : 0.00
                row += ", \(amount)"
            }
            section += row + "\n"
        }
        return section + "\n"
    }

    private func createTotalBalanceSection(group: Groups, allMemberIDs: Set<String>) -> String {
        let date = Date()
        var section = "\(escapeCSV(date.numericDate)), Total balance, , , INR"

        for member in allMemberIDs {
            if let memberBalance = group.balances.first(where: { $0.id == member }) {
                section += ", \(memberBalance.balance)"
            } else {
                section += ", 0.00"  // Add 0 if no balance is found
            }
        }
        return section + "\n"
    }
}
