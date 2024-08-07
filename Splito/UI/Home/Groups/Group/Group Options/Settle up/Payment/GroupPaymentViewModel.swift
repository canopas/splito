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
    @Published private(set) var maximumDate = Calendar.current.date(byAdding: .year, value: 0, to: Date()) ?? Date()

    @Published private(set) var payer: AppUser?
    @Published private(set) var receiver: AppUser?
    @Published private(set) var viewState: ViewState = .initial

    @Published private(set) var dismissPaymentFlow: () -> Void

    var payerName: String {
        guard let user = preference.user else { return "" }
        return user.id == payerId ? "You" : payer?.nameWithLastInitial ?? "Unknown"
    }

    var payableName: String {
        guard let user = preference.user else { return "" }
        return user.id == receiverId ? "You" : receiver?.nameWithLastInitial ?? "Unknown"
    }

    let transactionId: String?
    private let groupId: String
    private let payerId: String
    private let receiverId: String
    private var transaction: Transactions?
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>, transactionId: String?, groupId: String, payerId: String, receiverId: String, amount: Double, dismissPaymentFlow: @escaping () -> Void) {
        self.router = router
        self.amount = abs(amount)
        self.groupId = groupId
        self.payerId = payerId
        self.receiverId = receiverId
        self.transactionId = transactionId
        self.dismissPaymentFlow = dismissPaymentFlow
        super.init()

        fetchTransaction()
        getPayerUserDetail()
        getPayableUserDetail()
    }

    // MARK: - Data Loading
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
                guard let self else { return }
                self.payer = user
            }.store(in: &cancelable)
    }

    private func getPayableUserDetail() {
        userRepository.fetchUserBy(userID: receiverId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.receiver = user
            }.store(in: &cancelable)
    }

    func handleSaveAction() {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "You must enter an amount.")
            return
        }
        guard let userId = preference.user?.id else { return }

        if let transaction {
            var newTransaction = transaction
            newTransaction.amount = amount
            newTransaction.date = .init(date: paymentDate)
            updateTransaction(transaction: newTransaction)
        } else {
            addTransaction(transaction: Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                                     amount: amount, date: .init(date: paymentDate)))
        }
    }

    private func addTransaction(transaction: Transactions) {
        showLoader = true
        transactionRepository.addTransaction(groupId: groupId, transaction: transaction)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showLoader = false
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.dismissPaymentFlow()
                self?.showLoader = false
            }.store(in: &cancelable)
    }

    private func updateTransaction(transaction: Transactions) {
        showLoader = true
        transactionRepository.updateTransaction(groupId: groupId, transaction: transaction)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showLoader = false
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.dismissPaymentFlow()
                self?.showLoader = false
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
