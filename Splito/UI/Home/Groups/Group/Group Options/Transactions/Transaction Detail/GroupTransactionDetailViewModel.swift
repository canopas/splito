//
//  GroupTransactionDetailViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/06/24.
//

import Data
import Foundation

class GroupTransactionDetailViewModel: BaseViewModel, ObservableObject {

    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var transaction: Transactions?
    @Published private(set) var transactionUsersData: [AppUser] = []
    @Published private(set) var viewState: ViewState = .loading

    @Published var showEditTransactionSheet = false

    let router: Router<AppRoute>
    let groupId: String
    let transactionId: String

    private var group: Groups?

    init(router: Router<AppRoute>, groupId: String, transactionId: String) {
        self.router = router
        self.groupId = groupId
        self.transactionId = transactionId
        super.init()
        fetchGroup()
    }

    // MARK: - Data Loading
    private func fetchGroup() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
            }.store(in: &cancelable)
    }

    func fetchTransaction() {
        viewState = .loading
        transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] transaction in
                guard let self else { return }
                self.transaction = transaction
                self.setTransactionUsersData()
            }.store(in: &cancelable)
    }

    private func setTransactionUsersData() {
        guard let transaction else { return }

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
            self.transactionUsersData = userData
            self.viewState = .initial
        }
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

    // MARK: - User Actions
    func handleEditBtnAction() {
        showEditTransactionSheet = true
    }

    func handleDeleteBtnAction() {
        showAlert = true
        alert = .init(title: "Delete Transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteTransaction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction() {
        viewState = .loading
        transactionRepository.deleteTransaction(groupId: groupId, transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                self?.updateGroupMemberBalance(updateType: .Delete)
                self?.router.pop()
            }.store(in: &cancelable)
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) {
        guard var group, let transaction else { return }

        let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
        group.balances = memberBalance

        groupRepository.updateGroup(group: group)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.showToastFor(toast: .init(type: .success, title: "Success",
                                                message: "Transaction deleted successfully."))
            }.store(in: &cancelable)
    }

    func dismissEditTransactionSheet() {
        showEditTransactionSheet = false
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupTransactionDetailViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
