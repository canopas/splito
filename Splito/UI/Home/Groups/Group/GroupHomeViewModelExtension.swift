//
//  GroupHomeViewModelExtension.swift
//  Splito
//
//  Created by Nirali Sonani on 21/10/24.
//

import Data
import SwiftUI
import BaseStyle

// MARK: - User Actions
extension GroupHomeViewModel {
    func getMemberDataBy(id: String) -> AppUser? {
        return groupUserData.first(where: { $0.id == id })
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
                      message: "This will restore all activities, expenses and transactions for this group.",
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
                try await self.groupRepository.updateGroup(group: group)
                await self.addLogForRestoreGroup()
                self.fetchGroupAndExpenses()
            } catch {
                self.handleServiceError()
            }
        }
    }

    private func addLogForRestoreGroup() async {
        guard let group, let user = preference.user else { return }

        var errors: [Error] = []
        await withTaskGroup(of: Void.self) { groupTasks in
            for memberId in group.members {
                groupTasks.addTask { [weak self] in
                    if let activity = createActivityLogForGroup(context: ActivityLogContext(group: group, type: .groupRestored, memberId: memberId, currentUser: user)) {
                        do {
                            try await self?.activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                        } catch {
                            errors.append(error)
                        }
                    }
                }
            }
        }

        handleActivityLogErrors(errors)
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
        guard let userId = preference.user?.id else { return }

        Task {
            do {
                var deletedExpense = expense
                deletedExpense.updatedBy = userId

                try await expenseRepository.deleteExpense(groupId: groupId, expense: deletedExpense)
                await updateGroupMemberBalance(expense: deletedExpense, updateType: .Delete)
                await addLogForDeleteExpense(deletedExpense: deletedExpense)
            } catch {
                showToastForError()
            }
        }
    }

    private func addLogForDeleteExpense(deletedExpense: Expense) async {
        guard let group, let user = preference.user else { return }

        var errors: [Error] = []
        let involvedUserIds = Set(deletedExpense.splitTo + Array(deletedExpense.paidBy.keys) + [user.id, deletedExpense.addedBy, deletedExpense.updatedBy])

        await withTaskGroup(of: Void.self) { groupTasks in
            for memberId in involvedUserIds {
                groupTasks.addTask { [weak self] in
                    if let activity = createActivityLogForExpense(context: ActivityLogContext(group: group, expense: deletedExpense, type: .expenseDeleted, memberId: memberId, currentUser: user)) {
                        do {
                            try await self?.activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                        } catch {
                            errors.append(error)
                        }
                    }
                }
            }
        }

        handleActivityLogErrors(errors)
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group else { return }
        let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
        group.balances = memberBalance

        do {
            try await groupRepository.updateGroup(group: group)
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
            if let user = await fetchUserData(for: newExpense.paidBy.keys.first ?? "") {
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
            if let user = await self?.fetchUserData(for: updatedExpense.paidBy.keys.first ?? "") {
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
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully"))
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
