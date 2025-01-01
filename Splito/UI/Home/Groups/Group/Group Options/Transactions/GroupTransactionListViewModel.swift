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

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var transactionsWithUser: [TransactionWithUser] = []
    @Published private(set) var filteredTransactions: [String: [TransactionWithUser]] = [:]

    @Published var transactions: [Transactions] = []
    @Published var selectedTab: DateRangeTabType = .thisMonth
    @Published private(set) var currentViewState: ViewState = .loading
    @Published private(set) var showScrollToTopBtn = false

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

        fetchInitialViewData()
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroup()
            await fetchTransactions()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                currentViewState = .initial
                return
            }
            self.group = group
            LogD("GroupTransactionListViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupTransactionListViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    func fetchTransactions(needToReload: Bool = false) async {
        guard hasMoreTransactions || needToReload else {
            currentViewState = .initial
            return
        }
        if lastDocument == nil {
            transactionsWithUser = []
        }

        do {
            let result = try await transactionRepository.fetchTransactionsBy(groupId: groupId, limit: TRANSACTIONS_LIMIT, lastDocument: lastDocument)
            transactions = lastDocument == nil ? result.transactions.uniqued() : (transactions + result.transactions.uniqued())
            lastDocument = result.lastDocument

            await combinedTransactionsWithUser(transactions: result.transactions.uniqued())
            hasMoreTransactions = !(result.transactions.count < TRANSACTIONS_LIMIT)
            currentViewState = .initial
            LogD("GroupTransactionListViewModel: \(#function) Payments fetched successfully.")
        } catch {
            LogE("GroupTransactionListViewModel: \(#function) Failed to fetch payments: \(error).")
            handleErrorState()
        }
    }

    func processTransactionsLoad(needToReload: Bool = false) {
        if needToReload { lastDocument = nil }
        Task {
            await fetchTransactions(needToReload: needToReload)
        }
    }

    private func combinedTransactionsWithUser(transactions: [Transactions]) async {
        var combinedData: [TransactionWithUser] = []

        for transaction in transactions {
            if let payer = await fetchUserData(for: transaction.payerId) {
                if let receiver = await fetchUserData(for: transaction.receiverId) {
                    combinedData.append(TransactionWithUser(transaction: transaction,
                                                            payer: payer, receiver: receiver))
                }
            }
        }

        transactionsWithUser.append(contentsOf: combinedData)
        filteredTransactionsForSelectedTab()
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        if let existingUser = groupMembers.first(where: { $0.id == userId }) {
            return existingUser // Return the available user from groupMembers
        } else {
            do {
                let user = try await groupRepository.fetchMemberBy(memberId: userId)
                if let user {
                    groupMembers.append(user)
                }
                LogD("GroupTransactionListViewModel: \(#function) Member fetched successfully.")
                return user
            } catch {
                currentViewState = .initial
                LogE("GroupTransactionListViewModel: \(#function) Failed to fetch member \(userId): \(error).")
                showToastForError()
                return nil
            }
        }
    }

    // MARK: - User Actions
    func showTransactionDeleteAlert(_ transaction: Transactions) {
        showAlert = true
        alert = .init(title: "Delete payment",
                      message: "Are you sure you want to delete this payment?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in
                        Task {
                            await self?.deleteTransaction(transaction: transaction)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func deleteTransaction(transaction: Transactions) async {
        guard let group, let transactionId = transaction.id,
              validateGroupMembers(transaction: transaction),
              let payer = await fetchUserData(for: transaction.payerId),
              let receiver = await fetchUserData(for: transaction.receiverId) else { return }

        do {
            let updatedTransaction = try await transactionRepository.deleteTransaction(group: group, transaction: transaction,
                                                                                       payer: payer, receiver: receiver)
            NotificationCenter.default.post(name: .deleteTransaction, object: updatedTransaction)
            await updateGroupMemberBalance(transaction: updatedTransaction, updateType: .Delete)
            LogD("GroupTransactionListViewModel: \(#function) Payment deleted successfully.")
        } catch {
            LogE("GroupTransactionListViewModel: \(#function) Failed to delete payment \(transactionId): \(error).")
            showToastForError()
        }
    }

    private func validateGroupMembers(transaction: Transactions) -> Bool {
        guard let group else {
            LogE("GroupTransactionListViewModel: \(#function) Missing required group.")
            return false
        }

        if !group.members.contains(transaction.payerId) || !group.members.contains(transaction.receiverId) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showAlertFor(message: "This payment involves a person who has left the group, and thus it can no longer be deleted. If you wish to change this payment, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func updateGroupMemberBalance(transaction: Transactions, updateType: TransactionUpdateType) async {
        guard var group, let userId = preference.user?.id, let transactionId = transaction.id else {
            LogE("GroupTransactionListViewModel: \(#function) Group or payment information not found.")
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            group.updatedAt = Timestamp()
            group.updatedBy = userId
            try await groupRepository.updateGroup(group: group, type: .none)
            NotificationCenter.default.post(name: .updateGroup, object: group)
            LogD("GroupTransactionListViewModel: \(#function) Member balance updated successfully.")
        } catch {
            LogE("GroupTransactionListViewModel: \(#function) Failed to update member balance for payment \(transactionId): \(error).")
            showToastForError()
        }
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
            return Date().monthWithYear
        }

        let currentYear = Calendar.current.component(.year, from: Date())

        var groupedTransactions: [String: [TransactionWithUser]] {
            Dictionary(grouping: transactionsWithUser.uniqued()) { transaction in
                transaction.transaction.date.dateValue().monthWithYear
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

        Task {
            if let index = transactionsWithUser.firstIndex(where: { $0.transaction.id == updatedTransaction.id }) {
                if let payer = await fetchUserData(for: updatedTransaction.payerId) {
                    if let receiver = await fetchUserData(for: updatedTransaction.receiverId) {
                        self.transactionsWithUser[index] = TransactionWithUser(transaction: updatedTransaction,
                                                                               payer: payer, receiver: receiver)
                    }
                }
                withAnimation {
                    filteredTransactionsForSelectedTab()
                }
            }
            if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
                transactions[index] = updatedTransaction
            }
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
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment deleted successfully."))
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
        }
    }

    private func handleErrorState() {
        if lastDocument == nil {
            handleServiceError()
        } else {
            currentViewState = .initial
            showToastForError()
        }
    }
}

// MARK: - View States
extension GroupTransactionListViewModel {
    enum ViewState {
        case loading
        case initial
        case noInternet
        case somethingWentWrong
    }
}

// Struct to hold combined transaction and user information
struct TransactionWithUser: Hashable {
    var transaction: Transactions
    let payer: AppUser?
    let receiver: AppUser?
}
