//
//  GroupPaymentViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import BaseStyle
import Foundation

class GroupPaymentViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published var amount: Double = 0
    @Published var paymentDate = Date()
    @Published private(set) var showLoader: Bool = false

    @Published private(set) var payer: AppUser?
    @Published private(set) var receiver: AppUser?
    @Published private(set) var viewState: ViewState = .loading

    var payerName: String {
        guard let user = preference.user else { return "" }
        return user.id == payerId ? "You" : payer?.nameWithLastInitial ?? "Unknown"
    }

    var payableName: String {
        guard let user = preference.user else { return "" }
        return user.id == receiverId ? "you" : receiver?.nameWithLastInitial ?? "unknown"
    }

    private var group: Groups?
    private let groupId: String

    let transactionId: String?
    private var payerId: String
    private var receiverId: String
    private var transaction: Transactions?
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>, transactionId: String?, groupId: String, payerId: String, receiverId: String, amount: Double) {
        self.router = router
        self.amount = abs(amount)
        self.groupId = groupId
        self.payerId = payerId
        self.receiverId = receiverId
        self.transactionId = transactionId

        super.init()

        fetchInitialViewData()
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroup()
            await fetchTransaction()
            await getPayerUserDetail()
            await getPayableUserDetail()
        }
    }

    func switchPayerAndReceiver() {
        let temp = payer
        payer = receiver
        receiver = temp

        payerId = payer?.id ?? ""
        receiverId = receiver?.id ?? ""
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            self.group = try await groupRepository.fetchGroupBy(id: groupId)
            self.viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    func fetchTransaction() async {
        guard let transactionId else { return }
        do {
            viewState = .loading
            self.transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            self.paymentDate = self.transaction?.date.dateValue() ?? Date.now
            self.viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Payment fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch payment \(transactionId): \(error).")
            handleServiceError()
        }
    }

    private func getPayerUserDetail() async {
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: payerId)
            if let user { payer = user }
            viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Payer fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch payer \(payerId): \(error).")
            handleServiceError()
        }
    }

    private func getPayableUserDetail() async {
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: receiverId)
            if let user { receiver = user }
            viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Payable fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch payable \(receiverId): \(error).")
            handleServiceError()
        }
    }

    func showSaveFailedError() {
        guard amount > 0 else { return }

        guard validateGroupMembers() else {
            showAlertFor(message: "This payment involves a person who has left the group, and thus it can no longer be edited. If you wish to change this payment, you must first add that person back to your group.")
            return
        }

        showToastFor(toast: ToastPrompt(type: .error, title: "Oops", message: "Failed to save payment transaction."))
    }

    private func validateGroupMembers() -> Bool {
        guard let group, let payer, let receiver else {
            LogE("GroupPaymentViewModel: \(#function) Missing required group or member information.")
            return false
        }

        return group.members.contains(payer.id) && group.members.contains(receiver.id)
    }

    func handleSaveAction() async -> Bool {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "Please enter an amount greater than zero.")
            return false
        }

        guard let userId = preference.user?.id else { return false }

        if let transaction {
            var newTransaction = transaction
            newTransaction.amount = amount
            newTransaction.date = .init(date: paymentDate)
            newTransaction.updatedBy = userId

            return await updateTransaction(transaction: newTransaction, oldTransaction: transaction)
        } else {
            let transaction = Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                           updatedBy: userId, amount: amount, date: .init(date: paymentDate))
            return await addTransaction(transaction: transaction)
        }
    }

    private func addTransaction(transaction: Transactions) async -> Bool {
        guard let group, let payer, let receiver else {
            LogE("GroupPaymentViewModel: \(#function) Missing required group or member information.")
            return false
        }
        do {
            showLoader = true

            self.transaction = try await transactionRepository.addTransaction(group: group, transaction: transaction,
                                                                              payer: payer, receiver: receiver)
            NotificationCenter.default.post(name: .addTransaction, object: transaction)
            await updateGroupMemberBalance(updateType: .Add)

            showLoader = false
            LogD("GroupPaymentViewModel: \(#function) Payment added successfully.")
            return true
        } catch {
            showLoader = false
            LogE("GroupPaymentViewModel: \(#function) Failed to add payment: \(error).")
            showToastForError()
            return false
        }
    }

    private func updateTransaction(transaction: Transactions, oldTransaction: Transactions) async -> Bool {
        guard let group, let transactionId, let payer, let receiver else {
            LogE("GroupPaymentViewModel: \(#function) Missing required group or member information.")
            return false
        }

        guard validateGroupMembers() else { return false }
        guard hasTransactionChanged(transaction, oldTransaction: oldTransaction) else { return true }

        do {
            showLoader = true

            self.transaction = try await transactionRepository.updateTransaction(group: group, transaction: transaction, oldTransaction: oldTransaction,
                                                                                 members: (payer, receiver), type: .transactionUpdated)

            defer {
                NotificationCenter.default.post(name: .updateTransaction, object: self.transaction)
            }

            await updateGroupMemberBalance(updateType: .Update(oldTransaction: oldTransaction))

            showLoader = false
            LogD("GroupPaymentViewModel: \(#function) Payment updated successfully.")
            return true
        } catch {
            showLoader = false
            LogE("GroupPaymentViewModel: \(#function) Failed to update payment \(transactionId): \(error).")
            showToastForError()
            return false
        }
    }

    private func hasTransactionChanged(_ transaction: Transactions, oldTransaction: Transactions) -> Bool {
        return oldTransaction.amount != transaction.amount ||
        oldTransaction.date.dateValue() != transaction.date.dateValue() ||
        oldTransaction.updatedBy != transaction.updatedBy ||
        oldTransaction.isActive != transaction.isActive
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) async {
        guard var group, let transaction, let transactionId = transaction.id else {
            LogE("GroupPaymentViewModel: \(#function) Transaction information not found.")
            showLoader = false
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group, type: .none)
            LogD("GroupPaymentViewModel: \(#function) Member balance updated successfully.")
        } catch {
            showLoader = false
            LogE("GroupPaymentViewModel: \(#function) Failed to update member balance for payment \(transactionId): \(error).")
            showToastForError()
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
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
