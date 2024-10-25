//
//  GroupTransactionDetailViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/06/24.
//

import Data
import Foundation

class GroupTransactionDetailViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository
    @Inject private var activityLogRepository: ActivityLogRepository

    @Published private(set) var transaction: Transactions?
    @Published private(set) var transactionUsersData: [AppUser] = []
    @Published private(set) var viewState: ViewState = .loading

    @Published var showEditTransactionSheet = false

    var group: Groups?
    let router: Router<AppRoute>
    let groupId: String
    let transactionId: String

    init(router: Router<AppRoute>, groupId: String, transactionId: String) {
        self.router = router
        self.groupId = groupId
        self.transactionId = transactionId
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(getUpdatedTransaction(notification:)), name: .updateTransaction, object: nil)

        fetchInitialTransactionData()
    }

    func fetchInitialTransactionData() {
        Task {
            await fetchGroup()
            await fetchTransaction()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            self.group = group
            viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func fetchTransaction() async {
        do {
            viewState = .loading
            let transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            self.transaction = transaction
            await setTransactionUsersData()
            self.viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    private func setTransactionUsersData() async {
        guard let transaction else { return }

        var userData: [AppUser] = []
        var members: [String] = []

        members.append(transaction.payerId)
        members.append(transaction.receiverId)
        members.append(transaction.addedBy)

        for member in members.uniqued() {
            if let user = await self.fetchUserData(for: member) {
                userData.append(user)
            }
        }

        self.transactionUsersData = userData
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
            viewState = .initial
            showToastForError()
            return nil
        }
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return transactionUsersData.first(where: { $0.id == id })
    }

    // MARK: - User Actions
    func handleEditBtnAction() {
        guard validateUserPermission(operationText: "edited", action: "edit") else { return }
        showEditTransactionSheet = true
    }

    func handleRestoreButtonAction() {
        showAlert = true
        alert = .init(title: "Restore transaction",
                      message: "Are you sure you want to restore this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: self.restoreTransaction,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    func restoreTransaction() {
        guard let group, group.isActive else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAlertFor(title: "Error",
                             message: "The group associated with this transaction has been deleted, so it cannot be restored.")
            }
            return
        }

        guard validateUserPermission(operationText: "restored", action: "restored") else { return }

        guard var transaction, let userId = preference.user?.id else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.viewState = .loading
                transaction.isActive = true
                transaction.updatedBy = userId

                try await self.transactionRepository.updateTransaction(groupId: groupId, transaction: transaction)
                await self.updateGroupMemberBalance(updateType: .Update(oldTransaction: transaction))
                await self.addLogForDeletedTransaction(type: .transactionRestored)

                self.viewState = .initial
                self.router.pop()
            } catch {
                self.viewState = .initial
                self.showToastForError()
            }
        }
    }

    func handleDeleteBtnAction() {
        showAlert = true
        alert = .init(title: "Delete Transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: self.deleteTransaction,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction() {
        guard validateUserPermission(operationText: "deleted", action: "delete") else { return }
        guard var transaction, let userId = preference.user?.id else { return }

        Task {
            do {
                viewState = .loading
                transaction.updatedBy = userId

                try await transactionRepository.deleteTransaction(groupId: groupId, transaction: transaction)
                NotificationCenter.default.post(name: .deleteTransaction, object: transaction)
                await updateGroupMemberBalance(updateType: .Delete)
                await addLogForDeletedTransaction(type: .transactionDeleted)

                viewState = .initial
                router.pop()
            } catch {
                viewState = .initial
                showToastForError()
            }
        }
    }

    private func validateUserPermission(operationText: String, action: String) -> Bool {
        guard let userId = preference.user?.id, let group, group.members.contains(userId) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showAlertFor(title: "Error",
                                  message: "This transaction could not be \(operationText). You do not have permission to \(action) this transaction, Sorry!")
            }
            return false
        }
        return true
    }

    private func addLogForDeletedTransaction(type: ActivityType) async {
        guard let group, let transaction, let user = preference.user else {
            viewState = .initial
            return
        }

        var errors: [Error] = []
        let payerName = getMemberDataBy(id: transaction.payerId)?.nameWithLastInitial ?? "Someone"
        let receiverName = getMemberDataBy(id: transaction.receiverId)?.nameWithLastInitial ?? "Someone"
        let involvedUserIds: Set<String> = [transaction.payerId, transaction.receiverId, transaction.addedBy, transaction.updatedBy]

        await withTaskGroup(of: Void.self) { groupTasks in
            for memberId in involvedUserIds {
                groupTasks.addTask { [weak self] in
                    guard let self else { return }
                    if let activity = createActivityLogForTransaction(context: ActivityLogContext(group: group, transaction: transaction, type: type, memberId: memberId, currentUser: user, payerName: payerName, receiverName: receiverName)) {
                        do {
                            try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                        } catch {
                            errors.append(error)
                        }
                    }
                }
            }
        }

        if !errors.isEmpty {
            viewState = .initial
            showToastForError()
        }
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) async {
        guard var group, let transaction else {
            viewState = .initial
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance

            try await groupRepository.updateGroup(group: group)
            showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction deleted successfully."))
        } catch {
            viewState = .initial
            showToastForError()
        }
    }

    @objc private func getUpdatedTransaction(notification: Notification) {
        guard let updatedTransaction = notification.object as? Transactions else { return }
        transaction = updatedTransaction
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
extension GroupTransactionDetailViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
