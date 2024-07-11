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
    @Inject private var expenseRepository: ExpenseRepository

    @Published var expense: Expense?
    @Published var expenseUsersData: [AppUser] = []
    @Published var viewState: ViewState = .initial

    @Published var showEditExpenseSheet = false

    var expenseId: String
    let router: Router<AppRoute>

    init(router: Router<AppRoute>, expenseId: String) {
        self.router = router
        self.expenseId = expenseId
    }

    // MARK: - Data Loading
    func fetchExpense() {
        viewState = .loading
        expenseRepository.fetchExpenseBy(expenseId: expenseId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expense in
                guard let self else { return }

                let queue = DispatchGroup()
                var userData: [AppUser] = []

                var members = expense.splitTo
                for (payer, _) in expense.paidBy {
                    members.append(payer)
                }
                members.append(expense.addedBy)

                for member in members.uniqued() {
                    queue.enter()
                    self.fetchUserData(for: member) { user in
                        userData.append(user)
                        queue.leave()
                    }
                }

                queue.notify(queue: .main) {
                    self.expense = expense
                    self.expenseUsersData = userData
                    self.viewState = .initial
                }
            }.store(in: &cancelable)
    }

    func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        userRepository.fetchUserBy(userID: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func dismissEditExpenseSheet() {
        showEditExpenseSheet = false
        fetchExpense()
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return expenseUsersData.first(where: { $0.id == id })
    }

    func handleEditBtnAction() {
        showEditExpenseSheet = true
    }

    func handleDeleteBtnAction() {
        showAlert = true
        alert = .init(title: "Delete expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteExpense() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteExpense() {
        viewState = .loading
        expenseRepository.deleteExpense(id: expenseId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                self?.router.pop()
            }.store(in: &cancelable)
    }

    func getSplitAmount(for member: String) -> String {
        guard let expense = expense else { return "" }

        let finalAmount = calculateSplitAmount(member: member, expense: expense)
        return finalAmount.formattedCurrency
    }
}

// MARK: - View States
extension ExpenseDetailsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
