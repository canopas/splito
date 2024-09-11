//
//  GroupTransactionListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/06/24.
//

import Data
import SwiftUI
import FirebaseFirestore

class GroupTransactionListViewModel: BaseViewModel, ObservableObject {

    private let TRANSACTIONS_LIMIT = 10

    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var transactionsWithUser: [TransactionWithUser] = []
    @Published private(set) var filteredTransactions: [String: [TransactionWithUser]] = [:]

    @Published var transactions: [Transactions] = []
    @Published var selectedTab: DateRangeTabType = .thisMonth
    @Published private(set) var currentViewState: ViewState = .loading
    @Published private(set) var showScrollToTopBtn = false

    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private var group: Groups?
    private let groupId: String
    private let router: Router<AppRoute>

    var hasMoreTransactions: Bool = true
    private var lastDocument: DocumentSnapshot?
    private var groupMembers: [AppUser] = []

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateTransaction(notification:)), name: .updateTransaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeleteTransaction(notification:)), name: .deleteTransaction, object: nil)

        fetchGroup()
        fetchTransactions()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    func fetchTransactions() {
        transactionsWithUser = []
        transactionRepository.fetchTransactionsBy(groupId: groupId, limit: TRANSACTIONS_LIMIT)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.lastDocument = result.lastDocument
                self.transactions = result.transactions.uniqued()

                self.combinedTransactionsWithUser(transactions: result.transactions)
                self.hasMoreTransactions = !(result.transactions.count < self.TRANSACTIONS_LIMIT)
            }.store(in: &cancelable)
    }

    func fetchMoreTransactions() {
        transactionRepository.fetchTransactionsBy(groupId: groupId, limit: TRANSACTIONS_LIMIT, lastDocument: lastDocument)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.lastDocument = result.lastDocument
                self.transactions.append(contentsOf: result.transactions.uniqued())

                self.combinedTransactionsWithUser(transactions: result.transactions.uniqued())
                self.hasMoreTransactions = !(result.transactions.count < self.TRANSACTIONS_LIMIT)
            }.store(in: &cancelable)
    }

    private func combinedTransactionsWithUser(transactions: [Transactions]) {
        let queue = DispatchGroup()
        var combinedData: [TransactionWithUser] = []

        for transaction in transactions {
            queue.enter()
            self.fetchUserData(for: transaction.payerId) { payer in
                self.fetchUserData(for: transaction.receiverId) { receiver in
                    combinedData.append(TransactionWithUser(transaction: transaction,
                                                            payer: payer, receiver: receiver))
                    queue.leave()
                }
            }
        }

        queue.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.transactionsWithUser.append(contentsOf: combinedData)
            self.filteredTransactionsForSelectedTab()
            self.currentViewState = .initial
        }
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        if let existingUser = groupMembers.first(where: { $0.id == userId }) {
            completion(existingUser) // Return the available user from groupMembers
        } else {
            groupRepository.fetchMemberBy(userId: userId)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleServiceError(error)
                    }
                } receiveValue: { user in
                    guard let user else { return }
                    self.groupMembers.append(user)
                    completion(user)
                }.store(in: &cancelable)
        }
    }

    // MARK: - User Actions
    func showTransactionDeleteAlert(_ transaction: Transactions) {
        showAlert = true
        alert = .init(title: "Delete Transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteTransaction(transaction: transaction) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction(transaction: Transactions) {
        guard let transactionId = transaction.id else { return }
        transactionRepository.deleteTransaction(groupId: groupId, transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.updateGroupMemberBalance(transaction: transaction, updateType: .Delete)
            }.store(in: &cancelable)
    }

    private func updateGroupMemberBalance(transaction: Transactions, updateType: TransactionUpdateType) {
        guard var group else { return }
        let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
        group.balances = memberBalance

        groupRepository.updateGroup(group: group)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { _ in
                NotificationCenter.default.post(name: .deleteTransaction, object: transaction)
            }.store(in: &cancelable)
    }

    func handleTransactionItemTap(_ transactionId: String?) {
        guard let transactionId else { return }
        router.push(.TransactionDetailView(transactionId: transactionId, groupId: groupId))
    }

    func handleTabItemSelection(_ selection: DateRangeTabType) {
        withAnimation(.easeInOut(duration: 0.3), {
            selectedTab = selection
            filteredTransactionsForSelectedTab()
        })
    }

    private func filteredTransactionsForSelectedTab() {
        var currentMonth: String {
            return GroupTransactionListViewModel.dateFormatter.string(from: Date())
        }

        let currentYear = Calendar.current.component(.year, from: Date())

        var groupedTransactions: [String: [TransactionWithUser]] {
            Dictionary(grouping: transactionsWithUser.uniqued()) { transaction in
                GroupTransactionListViewModel.dateFormatter.string(from: transaction.transaction.date.dateValue())
            }
        }

        switch selectedTab {
        case .thisMonth:
            filteredTransactions = groupedTransactions.filter { $0.key == currentMonth }
        case .thisYear:
            filteredTransactions = groupedTransactions.filter { _, transactions in
                transactions.contains { transaction in
                    let date = transaction.transaction.date.dateValue()
                    let year = Calendar.current.component(.year, from: date)
                    return year == currentYear
                }
            }
        case .all:
            filteredTransactions = groupedTransactions
        }
    }

    func manageScrollToTopBtnVisibility(_ value: Bool) {
        showScrollToTopBtn = value
    }

    @objc private func handleUpdateTransaction(notification: Notification) {
        guard let updatedTransaction = notification.object as? Transactions else { return }

        // Update transactionsWithUser
        if let index = transactionsWithUser.firstIndex(where: { $0.transaction.id == updatedTransaction.id }) {
            self.transactionsWithUser[index].transaction = updatedTransaction
            withAnimation {
                self.filteredTransactionsForSelectedTab()
            }
        }

        if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
            transactions[index] = updatedTransaction
        }
    }

    @objc private func handleDeleteTransaction(notification: Notification) {
        guard let deletedTransaction = notification.object as? Transactions else { return }

        transactionsWithUser.removeAll { $0.transaction.id == deletedTransaction.id }
        transactions.removeAll { $0.id == deletedTransaction.id }

        if let key = filteredTransactions.keys.first(where: { key in
            filteredTransactions[key]?.contains(where: { $0.transaction.id == deletedTransaction.id }) == true
        }) {
            withAnimation {
                filteredTransactions[key]?.removeAll(where: { $0.transaction.id == deletedTransaction.id })
                // If the array is now empty, remove the key (month) from the dictionary
                if filteredTransactions[key]?.isEmpty == true {
                    filteredTransactions.removeValue(forKey: key)
                }
            }
        }
        showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction deleted successfully."))
    }

    // MARK: - Helper Methods
    func sortMonthYearStrings(_ s1: String, _ s2: String) -> Bool {
        guard let date1 = GroupTransactionListViewModel.dateFormatter.date(from: s1),
              let date2 = GroupTransactionListViewModel.dateFormatter.date(from: s2) else {
            return false
        }

        let components1 = Calendar.current.dateComponents([.year, .month], from: date1)
        let components2 = Calendar.current.dateComponents([.year, .month], from: date2)

        // Compare years first
        if components1.year != components2.year {
            return (components1.year ?? 0) > (components2.year ?? 0)
        } else {
            return (components1.month ?? 0) > (components2.month ?? 0)
        }
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        currentViewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupTransactionListViewModel {
    enum ViewState: Equatable {
        static func == (lhs: GroupTransactionListViewModel.ViewState, rhs: GroupTransactionListViewModel.ViewState) -> Bool {
            lhs.key == rhs.key
        }

        case loading
        case initial

        var key: String {
            switch self {
            case .loading:
                return "loading"
            case .initial:
                return "initial"
            }
        }
    }
}

// Struct to hold combined transaction and user information
struct TransactionWithUser: Hashable {
    var transaction: Transactions
    let payer: AppUser?
    let receiver: AppUser?
}
