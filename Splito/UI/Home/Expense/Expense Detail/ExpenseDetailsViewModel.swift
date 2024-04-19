//
//  ExpenseDetailsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/04/24.
//

import Data
import Combine

class ExpenseDetailsViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var expense: Expense?
    @Published var expenseUsersData: [AppUser] = []
    @Published var viewState: ViewState = .initial

    var expenseId: String
    let router: Router<AppRoute>

    init(router: Router<AppRoute>, expenseId: String) {
        self.router = router
        self.expenseId = expenseId
        super.init()
        print("XXX --- ID: \(expenseId)")
        self.fetchExpense()
    }

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
                self.expense = expense
                self.fetchUserData(for: expense.paidBy) { user in
                    self.expenseUsersData.append(user)
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

    func getMemberDataBy(id: String) -> AppUser? {
        return expenseUsersData.first(where: { $0.id == id })
    }

    func handleEditBtnAction() {
        router.push(.AddExpenseView(expenseId: expenseId))
    }

    func handleDeleteBtnAction() {
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
}

// MARK: - View States
extension ExpenseDetailsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
