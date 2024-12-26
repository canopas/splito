//
//  ExpenseDetailsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/04/24.
//

import Data
import SwiftUI
import BaseStyle
import FirebaseFirestore

class ExpenseDetailsViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published private(set) var expense: Expense?
    @Published private(set) var expenseUsersData: [AppUser] = []
    @Published private(set) var viewState: ViewState = .loading

    @Published var expenseNote: String = ""
    @Published private(set) var groupImageUrl: String = ""

    @Published var showAddNoteEditor = false
    @Published var showEditExpenseSheet = false

    var group: Groups?
    var groupId: String
    var expenseId: String
    let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String, expenseId: String) {
        self.router = router
        self.groupId = groupId
        self.expenseId = expenseId
        super.init()

        fetchGroupAndExpenseData()
        NotificationCenter.default.addObserver(self, selector: #selector(getUpdatedExpense(notification:)),
                                               name: .updateExpense, object: nil)
    }

    func fetchGroupAndExpenseData() {
        Task {
            await fetchGroup()
            await fetchExpense()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            group = try await groupRepository.fetchGroupBy(id: groupId)
            if let imageUrl = group?.imageUrl {
                self.groupImageUrl = imageUrl
            }
            viewState = .initial
            LogD("ExpenseDetailsViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    func fetchExpense() async {
        do {
            viewState = .loading
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            await processExpense(expense: expense)
            viewState = .initial
            LogD("ExpenseDetailsViewModel: \(#function) Expense fetched successfully.")
        } catch {
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch expense \(expenseId): \(error).")
            handleServiceError()
        }
    }

    func processExpense(expense: Expense) async {
        var userData: [AppUser] = []

        var members = expense.splitTo
        for (payer, _) in expense.paidBy {
            members.append(payer)
        }
        members.append(expense.addedBy)

        for member in members.uniqued() {
            if let user = await fetchUserData(for: member) {
                userData.append(user)
            }
        }

        self.expense = expense
        self.expenseNote = expense.note ?? ""
        self.expenseUsersData = userData
    }

    func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let member = try await userRepository.fetchUserBy(userID: userId)
            LogD("ExpenseDetailsViewModel: \(#function) Member fetched successfully.")
            return member
        } catch {
            viewState = .initial
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch member \(userId): \(error).")
            showToastForError()
            return nil
        }
    }

    // MARK: - User Actions
    func getMemberDataBy(id: String) -> AppUser? {
        return expenseUsersData.first(where: { $0.id == id })
    }

    func handleNoteTap() {
        guard let expense, expense.isActive, let userId = preference.user?.id,
              let group, group.members.contains(userId) else { return }
        showAddNoteEditor = true
    }

    func handleEditBtnAction() {
        guard validateUserPermission(operationText: "edited", action: "edit"),
              validateGroupMembers(action: "edited") else { return }
        showEditExpenseSheet = true
    }

    func handleRestoreButtonAction() {
        showAlert = true
        alert = .init(title: "Restore expense",
                      message: "Are you sure you want to restore this expense?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: self.restoreExpense,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    func restoreExpense() {
        guard let group, group.isActive else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAlertFor(title: "Error",
                                  message: "The group associated with this expense has been deleted, so it cannot be restored.")
            }
            return
        }

        guard var expense, let userId = preference.user?.id,
              validateUserPermission(operationText: "restored", action: "restored"),
              validateGroupMembers(action: "restored") else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.viewState = .loading
                expense.isActive = true
                expense.updatedBy = userId
                expense.updatedAt = Timestamp()

                self.expense = try await self.expenseRepository.updateExpense(group: group, expense: expense,
                                                                              oldExpense: expense, type: .expenseRestored)
                let expenseInfo: [String: Any] = ["groupId": groupId, "expense": expense]
                NotificationCenter.default.post(name: .addExpense, object: nil, userInfo: expenseInfo)
                await self.updateGroupMemberBalance(updateType: .Add)

                self.viewState = .initial
                LogD("ExpenseDetailsViewModel: \(#function) Expense restored successfully.")
                self.router.pop()
            } catch {
                LogE("ExpenseDetailsViewModel: \(#function) Failed to restore expense \(expenseId): \(error).")
                self.handleServiceError()
            }
        }
    }

    func handleDeleteButtonAction() {
        showAlert = true
        alert = .init(title: "Delete Expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: self.deleteExpense,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteExpense() {
        guard let group, let expense, validateUserPermission(operationText: "deleted", action: "delete"),
              validateGroupMembers(action: "deleted") else { return }

        Task {
            do {
                viewState = .loading
                self.expense = try await expenseRepository.deleteExpense(group: group, expense: expense)
                NotificationCenter.default.post(name: .deleteExpense, object: self.expense)
                await self.updateGroupMemberBalance(updateType: .Delete)

                viewState = .initial
                LogD("ExpenseDetailsViewModel: \(#function) Expense deleted successfully.")
                router.pop()
            } catch {
                viewState = .initial
                LogE("ExpenseDetailsViewModel: \(#function) Failed to delete expense \(expenseId): \(error).")
                showToastForError()
            }
        }
    }

    private func validateGroupMembers(action: String) -> Bool {
        guard let group, let expense else {
            LogE("ExpenseDetailsViewModel: \(#function) Missing required group or expense.")
            return false
        }

        let missingMemberIds = Set(expense.splitTo + Array(expense.paidBy.keys)).subtracting(group.members)

        if !missingMemberIds.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showAlertFor(message: "This expense involves a person who has left the group, and thus it can no longer be \(action). If you wish to change this expense, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func validateUserPermission(operationText: String, action: String) -> Bool {
        guard let userId = preference.user?.id, let group, group.members.contains(userId) else {
            DispatchQueue.main.async {
                self.showAlertFor(title: "Error",
                                  message: "This expense could not be \(operationText). You do not have permission to \(action) this expense, Sorry!")
            }
            return false
        }
        return true
    }

    private func updateGroupMemberBalance(updateType: ExpenseUpdateType) async {
        guard var group, let userId = preference.user?.id, let expense else {
            LogE("ExpenseDetailsViewModel: \(#function) Group or expense information not found.")
            viewState = .initial
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
            group.balances = memberBalance
            group.updatedAt = Timestamp()
            group.updatedBy = userId
            try await groupRepository.updateGroup(group: group, type: .none)
            LogD("ExpenseDetailsViewModel: \(#function) Member balance updated successfully.")
        } catch {
            viewState = .initial
            LogE("ExpenseDetailsViewModel: \(#function) Failed to update member balance for expense \(expenseId): \(error).")
            showToastForError()
        }
    }

    func getSplitAmount(for member: String) -> String {
        guard let expense else { return "" }
        let finalAmount = expense.getTotalSplitAmountOf(member: member)
        return finalAmount.formattedCurrency
    }

    @objc private func getUpdatedExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }

        viewState = .loading
        Task {
            await processExpense(expense: updatedExpense)
            viewState = .initial
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            viewState = .noInternet
        } else {
            viewState = .somethingWentWrong
        }
    }
}

// MARK: - View States
extension ExpenseDetailsViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
