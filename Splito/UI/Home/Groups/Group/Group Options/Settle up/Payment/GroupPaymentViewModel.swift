//
//  GroupPaymentViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
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
        return user.id == receiverId ? "You" : receiver?.nameWithLastInitial ?? "Unknown"
    }

    private var group: Groups?
    private let groupId: String

    let transactionId: String?
    private let payerId: String
    private let receiverId: String
    private var transaction: Transactions?
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>, transactionId: String?, groupId: String,
         payerId: String, receiverId: String, amount: Double) {
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

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            self.group = group
            self.viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func fetchTransaction() async {
        guard let transactionId else { return }
        do {
            viewState = .loading
            let transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            self.transaction = transaction
            self.paymentDate = transaction.date.dateValue()
            self.viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    private func getPayerUserDetail() async {
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: payerId)
            if let user { payer = user }
            viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    private func getPayableUserDetail() async {
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: receiverId)
            if let user { receiver = user }
            viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func handleSaveAction(completion: @escaping (Bool) -> Void) {
        Task {
            await performSaveAction(completion: completion)
        }
    }

    private func performSaveAction(completion: (Bool) -> Void) async {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "You must enter an amount.")
            return
        }

        guard let userId = preference.user?.id else { return }

        if let transaction {
            var newTransaction = transaction
            newTransaction.amount = amount
            newTransaction.date = .init(date: paymentDate)

            await updateTransaction(transaction: newTransaction, oldTransaction: transaction, completion: completion)
        } else {
            let transaction = Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                           amount: amount, date: .init(date: paymentDate))
            await addTransaction(transaction: transaction, completion: completion)
        }
    }

    private func addTransaction(transaction: Transactions, completion: (Bool) -> Void) async {
        do {
            showLoader = true
            let transaction = try await transactionRepository.addTransaction(groupId: groupId, transaction: transaction)
            await updateGroupMemberBalance(transaction: transaction, updateType: .Add)
            NotificationCenter.default.post(name: .addTransaction, object: transaction)
            showLoader = false
            completion(true)
        } catch {
            showLoader = false
            completion(false)
            showToastForError()
        }
    }

    private func updateTransaction(transaction: Transactions, oldTransaction: Transactions, completion: (Bool) -> Void) async {
        do {
            showLoader = true
            try await transactionRepository.updateTransaction(groupId: groupId, transaction: transaction)
            await updateGroupMemberBalance(transaction: transaction, updateType: .Update(oldTransaction: oldTransaction))
            NotificationCenter.default.post(name: .updateTransaction, object: transaction)
            showLoader = false
            completion(true)
        } catch {
            showLoader = false
            completion(false)
            showToastForError()
        }
    }

    private func updateGroupMemberBalance(transaction: Transactions, updateType: TransactionUpdateType) async {
        guard var group else {
            showLoader = false
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group)
        } catch {
            showLoader = false
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
