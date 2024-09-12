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

        NotificationCenter.default.addObserver(self, selector: #selector(getUpdatedTransaction(notification:)), name: .updateTransaction, object: nil)

        Task {
            await fetchGroup()
            await fetchTransaction()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            self.group = group
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }

    func fetchTransaction() async {
        viewState = .loading

        do {
            let transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            self.transaction = transaction
            await setTransactionUsersData()
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }

    private func setTransactionUsersData() async {
        guard let transaction else { return }

        let queue = DispatchGroup()
        var userData: [AppUser] = []

        var members: [String] = []
        members.append(transaction.payerId)
        members.append(transaction.receiverId)
        members.append(transaction.addedBy)

        for member in members.uniqued() {
            queue.enter()
            if let user = await self.fetchUserData(for: member) {
                userData.append(user)
                queue.leave()
            }
        }

        queue.notify(queue: .main) {
            self.transactionUsersData = userData
            self.viewState = .initial
        }
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let user = try await userRepository.fetchUserBy(userID: userId)
            guard let user else {
                viewState = .initial
                return nil
            }
            return user
        } catch {
            handleServiceError(error as! ServiceError)
            return nil
        }
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
                      positiveBtnAction: {
            Task {
                await self.deleteTransaction()
            }
        },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction() async {
        viewState = .loading

        do {
            try await transactionRepository.deleteTransaction(groupId: groupId, transactionId: transactionId)
            viewState = .initial
            NotificationCenter.default.post(name: .deleteTransaction, object: transaction)
            await updateGroupMemberBalance(updateType: .Delete)
            router.pop()
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) async {
        guard var group, let transaction else { return }

        let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
        group.balances = memberBalance

        do {
            try await groupRepository.updateGroup(group: group)
            showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction deleted successfully."))
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }

    @objc private func getUpdatedTransaction(notification: Notification) {
        guard let updatedTransaction = notification.object as? Transactions else { return }
        transaction = updatedTransaction
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
