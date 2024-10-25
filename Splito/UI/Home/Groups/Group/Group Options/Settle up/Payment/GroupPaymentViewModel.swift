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
    @Inject private var activityLogRepository: ActivityLogRepository
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
            newTransaction.updatedBy = userId

            await updateTransaction(transaction: newTransaction, oldTransaction: transaction, completion: completion)
        } else {
            let transaction = Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                           updatedBy: userId, amount: amount, date: .init(date: paymentDate))
            await addTransaction(transaction: transaction, completion: completion)
        }
    }

    private func addTransaction(transaction: Transactions, completion: (Bool) -> Void) async {
        do {
            showLoader = true

            self.transaction = try await transactionRepository.addTransaction(groupId: groupId, transaction: transaction)
            NotificationCenter.default.post(name: .addTransaction, object: transaction)
            await updateGroupMemberBalance(transaction: transaction, updateType: .Add)
            await addLogForAddTransaction()

            showLoader = false
            completion(true)
        } catch {
            showLoader = false
            completion(false)
            showToastForError()
        }
    }

    private func addLogForAddTransaction() async {
        guard let transaction, let payer, let receiver, let userId = preference.user?.id else {
            showLoader = false
            return
        }

        var errors: [Error] = []
        var payerName = payer.nameWithLastInitial
        var receiverName = receiver.nameWithLastInitial
        let involvedUserIds: Set<String> = [transaction.payerId, transaction.receiverId, transaction.addedBy]

        await withTaskGroup(of: Void.self) { group in
            for memberId in involvedUserIds {
                group.addTask { [weak self] in
                    guard let self else { return }
                    if userId == transaction.payerId {
                        payerName = (memberId == transaction.payerId) ? "You" : payer.nameWithLastInitial
                        receiverName = (memberId == transaction.receiverId) ? "you" : receiver.nameWithLastInitial
                    }
                    await addActivityLog(type: .transactionAdded, memberId: memberId, payerName: payerName, receiverName: receiverName, errors: &errors)
                }
            }
        }

        handleActivityLogErrors(errors)
    }

    private func updateTransaction(transaction: Transactions, oldTransaction: Transactions, completion: (Bool) -> Void) async {
        guard let userId = preference.user?.id else { return }

        do {
            showLoader = true
            self.transaction = transaction

            try await transactionRepository.updateTransaction(groupId: groupId, transaction: transaction)
            NotificationCenter.default.post(name: .updateTransaction, object: transaction)
            await updateGroupMemberBalance(transaction: transaction, updateType: .Update(oldTransaction: oldTransaction))
            await addLogForUpdateTransaction()

            showLoader = false
            completion(true)
        } catch {
            showLoader = false
            completion(false)
            showToastForError()
        }
    }

    private func addLogForUpdateTransaction() async {
        guard let transaction = self.transaction else {
            showLoader = false
            return
        }

        var errors: [Error] = []
        let involvedUserIds: Set<String> = [transaction.payerId, transaction.receiverId, transaction.addedBy, transaction.updatedBy]

        await withTaskGroup(of: Void.self) { group in
            for memberId in involvedUserIds {
                group.addTask { [weak self] in
                    guard let self else { return }
                    await addActivityLog(type: .transactionUpdated, memberId: memberId, payerName: payer?.nameWithLastInitial, receiverName: receiver?.nameWithLastInitial, errors: &errors)
                }
            }
        }

        handleActivityLogErrors(errors)
    }

    private func addActivityLog(type: ActivityType, memberId: String, payerName: String?, receiverName: String?, errors: inout [Error]) async {
        guard let transaction, let user = preference.user else {
            showLoader = false
            return
        }

        if let activity = createActivityLogForTransaction(context: ActivityLogContext(group: group, transaction: transaction, type: type, memberId: memberId, currentUser: user, payerName: payerName ?? "Someone", receiverName: receiverName ?? "Someone")) {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
            } catch {
                errors.append(error)
            }
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

    private func handleActivityLogErrors(_ errors: [Error]) {
        if !errors.isEmpty {
            showLoader = false
            showToastForError()
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
