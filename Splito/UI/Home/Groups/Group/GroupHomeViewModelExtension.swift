//
//  GroupHomeViewModelExtension.swift
//  Splito
//
//  Created by Amisha Italiya on 21/10/24.
//

import Data
import SwiftUI
import BaseStyle

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
            showAlertFor(title: "Oops", message: "You're the only member in this group, and there's no point in settling up with yourself :)")
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
                      positiveBtnAction: self.restoreGroup,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    func restoreGroup() {
        guard var group, let userId = preference.user?.id else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.groupState = .loading
                group.isActive = true
                group.updatedBy = userId
                try await self.groupRepository.updateGroup(group: group, type: .groupRestored)
                self.fetchGroupAndExpenses()
            } catch {
                self.handleServiceError()
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
        guard let group, let userId = preference.user?.id, validateGroupMembers(expense: expense) else { return }

        Task {
            do {
                var deletedExpense = expense
                deletedExpense.updatedBy = userId

                try await expenseRepository.deleteExpense(group: group, expense: deletedExpense)
                await updateGroupMemberBalance(expense: deletedExpense, updateType: .Delete)
            } catch {
                showToastForError()
            }
        }
    }

    private func validateGroupMembers(expense: Expense) -> Bool {
        guard let group else {
            LogE("GroupHomeViewModel: Missing required group.")
            return false
        }

        let missingMemberIds = Set(expense.splitTo + Array(expense.paidBy.keys)).subtracting(group.members)

        if !missingMemberIds.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showAlertFor(message: "This expense involves a person who has left the group, and thus it can no longer be deleted. If you wish to change this expense, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group else { return }
        let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
        group.balances = memberBalance

        do {
            try await groupRepository.updateGroup(group: group, type: .none)
            NotificationCenter.default.post(name: .deleteExpense, object: expense)
        } catch {
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

        Task {
            expenses.append(newExpense)
            if let user = await fetchMemberData(for: newExpense.paidBy.keys.first ?? "") {
                let newExpenseWithUser = ExpenseWithUser(expense: newExpense, user: user)
                withAnimation {
                    expensesWithUser.append(newExpenseWithUser)
                }
            }
        }
        refreshGroupData()
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
                    }
                }
            }
        }
        refreshGroupData()
    }

    @objc func handleDeleteExpense(notification: Notification) {
        guard let deletedExpense = notification.object as? Expense else { return }
        expenses.removeAll { $0.id == deletedExpense.id }
        if let index = expensesWithUser.firstIndex(where: { $0.expense.id == deletedExpense.id }) {
            withAnimation {
                expensesWithUser.remove(at: index)
                showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully."))
            }
        }
        refreshGroupData()
    }

    @objc func handleTransaction(notification: Notification) {
        refreshGroupData()
    }

    @objc func handleAddTransaction(notification: Notification) {
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully."))
        showSettleUpSheet = false
        refreshGroupData()
    }

    @objc func handleUpdateGroup(notification: Notification) {
        guard let updatedGroup = notification.object as? Groups else { return }
        group?.name = updatedGroup.name
    }

    private func refreshGroupData() {
        Task {
            await self.fetchGroup()
            self.fetchGroupBalance()
            NotificationCenter.default.post(name: .updateGroup, object: group)
        }
    }
}
