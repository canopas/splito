//
//  TransactionDetailViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 17/06/24.
//

import Data
import Combine
import SwiftUI

class TransactionDetailViewModel: BaseViewModel, ObservableObject {

    @Inject private var userRepository: UserRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var transaction: Transactions?
    @Published private(set) var transactionUsersData: [AppUser] = []
    @Published private(set) var viewState: ViewState = .initial

    @Published var showEditTransactionSheet = false

    @Published private(set) var transactionId: String
    @Published private(set) var groupId: String

    let router: Router<AppRoute>

    init(router: Router<AppRoute>, transactionId: String, groupId: String) {
        self.router = router
        self.transactionId = transactionId
        self.groupId = groupId
    }

    // MARK: - Data Loading
    func fetchTransaction() {
        viewState = .loading
        transactionRepository.fetchTransactionBy(transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] transaction in
                guard let self else { return }

                let queue = DispatchGroup()
                var userData: [AppUser] = []

                var members: [String] = []
                members.append(transaction.payerId)
                members.append(transaction.receiverId)
                members.append(transaction.addedBy)

                for member in members.uniqued() {
                    queue.enter()
                    self.fetchUserData(for: member) { user in
                        userData.append(user)
                        queue.leave()
                    }
                }

                queue.notify(queue: .main) {
                    self.transaction = transaction
                    self.transactionUsersData = userData
                    self.viewState = .initial
                }
            }.store(in: &cancelable)
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        userRepository.fetchUserBy(userID: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return transactionUsersData.first(where: { $0.id == id })
    }

    private func deleteTransaction() {
        viewState = .loading

        transactionRepository.deleteTransaction(transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                self?.router.pop()
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func handleEditBtnAction() {
        showEditTransactionSheet = true
    }

    func dismissEditTransactionSheet() {
        showEditTransactionSheet = false
        fetchTransaction()
    }

    func handleDeleteBtnAction() {
        showAlert = true
        alert = .init(title: "Delete transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteTransaction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension TransactionDetailViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
