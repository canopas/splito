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

    init(router: Router<AppRoute>, transactionId: String?, groupId: String, payerId: String, receiverId: String, amount: Double) {
        self.router = router
        self.amount = abs(amount)
        self.groupId = groupId
        self.payerId = payerId
        self.receiverId = receiverId
        self.transactionId = transactionId

        super.init()

        fetchGroup()
        fetchTransaction()
        getPayerUserDetail()
        getPayableUserDetail()
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
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    func fetchTransaction() {
        guard let transactionId else { return }

        viewState = .loading
        transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] transaction in
                guard let self else { return }
                self.transaction = transaction
                self.paymentDate = transaction.date.dateValue()
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    private func getPayerUserDetail() {
        userRepository.fetchUserBy(userID: payerId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] user in
                self?.payer = user
            }.store(in: &cancelable)
    }

    private func getPayableUserDetail() {
        userRepository.fetchUserBy(userID: receiverId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] user in
                self?.receiver = user
            }.store(in: &cancelable)
    }

    func handleSaveAction(completion: @escaping () -> Void) {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "You must enter an amount.")
            return
        }
        guard let userId = preference.user?.id else { return }

        if let transaction {
            var newTransaction = transaction
            newTransaction.amount = amount
            newTransaction.date = .init(date: paymentDate)
            updateTransaction(transaction: newTransaction, oldTransaction: transaction, completion: completion)
        } else {
            addTransaction(transaction: Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                                     amount: amount, date: .init(date: paymentDate)), completion: completion)
        }
    }

    private func addTransaction(transaction: Transactions, completion: @escaping () -> Void) {
        showLoader = true
        transactionRepository.addTransaction(groupId: groupId, transaction: transaction)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showLoader = false
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.showLoader = false
                NotificationCenter.default.post(name: .addTransaction, object: transaction)
                self?.updateGroupMemberBalance(transaction: transaction, updateType: .Add, completion: completion)
            }.store(in: &cancelable)
    }

    private func updateTransaction(transaction: Transactions, oldTransaction: Transactions, completion: @escaping () -> Void) {
        showLoader = true
        transactionRepository.updateTransaction(groupId: groupId, transaction: transaction)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showLoader = false
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.showLoader = false
                NotificationCenter.default.post(name: .updateTransaction, object: transaction)
                self?.updateGroupMemberBalance(transaction: transaction, updateType: .Update(oldTransaction: oldTransaction), completion: completion)
            }.store(in: &cancelable)
    }

    private func updateGroupMemberBalance(transaction: Transactions, updateType: TransactionUpdateType, completion: @escaping () -> Void) {
        guard var group else { return }

        let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
        group.balances = memberBalance

        groupRepository.updateGroup(group: group)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                completion()
            }.store(in: &cancelable)
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
