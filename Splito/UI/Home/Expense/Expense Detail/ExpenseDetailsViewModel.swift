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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            group = try await groupRepository.fetchGroupBy(id: groupId)
            if let imageUrl = group?.imageUrl {
                self.groupImageUrl = imageUrl
            }
        } catch {
            showToastFor(error as! ServiceError)
        }
    }

    func fetchExpense() async {
        do {
            viewState = .loading
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            await processExpense(expense: expense)
        } catch {
            viewState = .initial
            showToastFor(error as! ServiceError)
        }
    }

    func processExpense(expense: Expense) async {
        let queue = DispatchGroup()
        var userData: [AppUser] = []

        var members = expense.splitTo
        for (payer, _) in expense.paidBy {
            members.append(payer)
        }
        members.append(expense.addedBy)

        for member in members.uniqued() {
            queue.enter()
            if let user = await fetchUserData(for: member) {
                userData.append(user)
            }
            queue.leave()
        }

        queue.notify(queue: .main) {
            self.expense = expense
            self.expenseUsersData = userData
            self.viewState = .initial
        }
    }

    func fetchUserData(for userId: String) async -> AppUser? {
        do {
            return try await userRepository.fetchUserBy(userID: userId)
        } catch {
            viewState = .initial
            showToastFor(error as! ServiceError)
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
            showToastFor(error as! ServiceError)
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
            showToastFor(error as! ServiceError)
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

    @objc private func getUpdatedExpense(notification: Notification) async {
        guard let updatedExpense = notification.object as? Expense else { return }
        viewState = .loading
        await processExpense(expense: updatedExpense)
    }
}

// MARK: - View States
extension ExpenseDetailsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
