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
        guard validateUserPermission(operationText: "edited", action: "edit"), validateGroupMembers(action: "edited") else { return }
        showEditTransactionSheet = true
    }

    func handleRestoreButtonAction() {
        showAlert = true
        alert = .init(title: "Restore payment",
                      message: "Are you sure you want to restore this payment?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: self.restoreTransaction,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    func restoreTransaction() {
        guard let group, group.isActive else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAlertFor(title: "Error",
                                  message: "The group associated with this payment has been deleted, so it cannot be restored.")
            }
            return
        }

        guard validateUserPermission(operationText: "restored", action: "restored"), validateGroupMembers(action: "restored") else { return }

        guard var transaction else {
            LogE("GroupTransactionDetailViewModel: \(#function) transaction not found.")
            return
        }

        Task { [weak self] in
            guard let self, let payer = getMemberDataBy(id: transaction.payerId),
                  let receiver = getMemberDataBy(id: transaction.receiverId) else { return }
            do {
                self.viewState = .loading
                transaction.isActive = true
                transaction.updatedBy = preference.user?.id ?? ""

                self.transaction = try await self.transactionRepository.updateTransaction(group: group, transaction: transaction, oldTransaction: transaction, members: (payer, receiver), type: .transactionRestored)
                await self.updateGroupMemberBalance(updateType: .Add)
                showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction restored successfully."))

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
        alert = .init(title: "Delete payment",
                      message: "Are you sure you want to delete this payment?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: self.deleteTransaction,
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction() {
        guard let transaction, validateUserPermission(operationText: "deleted", action: "delete"), validateGroupMembers(action: "deleted") else { return }

        Task { [weak self] in
            guard let self, let group, let payer = getMemberDataBy(id: transaction.payerId),
                  let receiver = getMemberDataBy(id: transaction.receiverId) else { return }
            do {
                viewState = .loading
                self.transaction = try await transactionRepository.deleteTransaction(group: group, transaction: transaction,
                                                                                     payer: payer, receiver: receiver)
                NotificationCenter.default.post(name: .deleteTransaction, object: self.transaction)
                await updateGroupMemberBalance(updateType: .Delete)
                self.showToastFor(toast: .init(type: .success, title: "Success", message: "Payment deleted successfully."))

                viewState = .initial
                router.pop()
            } catch {
                viewState = .initial
                showToastForError()
            }
        }
    }

    private func validateGroupMembers(action: String) -> Bool {
        guard let group, let transaction else {
            LogE("GroupTransactionDetailViewModel: Missing required group or transaction.")
            return false
        }

        let isPayerInGroup = group.members.contains(transaction.payerId)
        let isReceiverInGroup = group.members.contains(transaction.receiverId)

        if !isPayerInGroup || !isReceiverInGroup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showAlertFor(message: "This payment involves a person who has left the group, and thus it can no longer be \(action). If you wish to change this payment, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func validateUserPermission(operationText: String, action: String) -> Bool {
        guard let userId = preference.user?.id, let group, group.members.contains(userId) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showAlertFor(title: "Error",
                                  message: "This payment could not be \(operationText). You do not have permission to \(action) this payment, Sorry!")
            }
            return false
        }
        return true
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) async {
        guard var group, let transaction else {
            viewState = .initial
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group, type: .none)
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
