//
//  ExpenseDetailsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/04/24.
//

import Data
import Combine
import SwiftUI

class ExpenseDetailsViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published private(set) var expense: Expense?
    @Published private(set) var expenseUsersData: [AppUser] = []
    @Published private(set) var viewState: ViewState = .initial

    @Published private(set) var groupImageUrl: String = ""
    @Published var showEditExpenseSheet = false

    var groupId: String
    var expenseId: String
    let router: Router<AppRoute>
    private var group: Groups?

    init(router: Router<AppRoute>, groupId: String, expenseId: String) {
        self.router = router
        self.groupId = groupId
        self.expenseId = expenseId
        super.init()

        Task {
            await fetchGroup()
            await fetchExpense()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(getUpdatedExpense(notification:)), name: .updateExpense, object: nil)
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            viewState = .loading
            group = try await groupRepository.fetchGroupBy(id: groupId)
            if let imageUrl = group?.imageUrl {
                self.groupImageUrl = imageUrl
            }
            viewState = .initial
        } catch {
            handleServiceError(error)
        }
    }

    func fetchExpense() async {
        do {
            viewState = .loading
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            await processExpense(expense: expense)
        } catch {
            viewState = .initial
            handleServiceError(error)
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
        self.expenseUsersData = userData
        self.viewState = .initial
    }

    func fetchUserData(for userId: String) async -> AppUser? {
        do {
            return try await userRepository.fetchUserBy(userID: userId)
        } catch {
            viewState = .initial
            handleServiceError(error)
            return nil
        }
    }

    // MARK: - User Actions
   func getMemberDataBy(id: String) -> AppUser? {
        return expenseUsersData.first(where: { $0.id == id })
    }

    func handleEditBtnAction() {
        showEditExpenseSheet = true
    }

    func handleDeleteBtnAction() async {
        showAlert = true
        alert = .init(title: "Delete Expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: {
            Task {
                await self.deleteExpense()
            }
        },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteExpense() async {
        do {
            viewState = .loading
            try await expenseRepository.deleteExpense(groupId: groupId, expenseId: expenseId)
            viewState = .initial
            NotificationCenter.default.post(name: .deleteExpense, object: expense)
            await self.updateGroupMemberBalance(updateType: .Delete)
            router.pop()
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    private func updateGroupMemberBalance(updateType: ExpenseUpdateType) async {
        guard var group, let expense else { return }

        let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
        group.balances = memberBalance

        do {
            try await groupRepository.updateGroup(group: group)
            viewState = .initial
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    func getSplitAmount(for member: String) -> String {
        guard let expense else { return "" }
        let finalAmount = expense.getTotalSplitAmountOf(member: member)
        return finalAmount.formattedCurrency
    }

    func handleBackBtnTap() {
        router.pop()
    }

    @objc private func getUpdatedExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }
        viewState = .loading
        Task {
            await processExpense(expense: updatedExpense)
        }
    }
}

// MARK: - View States
extension ExpenseDetailsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
