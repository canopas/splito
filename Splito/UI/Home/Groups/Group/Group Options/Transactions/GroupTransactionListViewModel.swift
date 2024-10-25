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
    @Inject private var activityLogRepository: ActivityLogRepository

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
            currentViewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func fetchTransactions() async {
        do {
            currentViewState = .loading
            transactionsWithUser = []

            let result = try await transactionRepository.fetchTransactionsBy(groupId: groupId, limit: TRANSACTIONS_LIMIT)
            lastDocument = result.lastDocument
            transactions = result.transactions.uniqued()

            await combinedTransactionsWithUser(transactions: result.transactions)
            hasMoreTransactions = !(result.transactions.count < TRANSACTIONS_LIMIT)
            currentViewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func loadMoreTransactions() {
        Task {
            await fetchMoreTransactions()
        }
    }

    private func fetchMoreTransactions() async {
        do {
            let result = try await transactionRepository.fetchTransactionsBy(groupId: groupId,
                                                                             limit: TRANSACTIONS_LIMIT, lastDocument: lastDocument)
            lastDocument = result.lastDocument
            transactions.append(contentsOf: result.transactions.uniqued())

            await combinedTransactionsWithUser(transactions: result.transactions.uniqued())
            hasMoreTransactions = !(result.transactions.count < TRANSACTIONS_LIMIT)
        } catch {
            showToastForError()
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

        self.transactionsWithUser.append(contentsOf: combinedData)
        self.filteredTransactionsForSelectedTab()
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        if let existingUser = groupMembers.first(where: { $0.id == userId }) {
            return existingUser // Return the available user from groupMembers
        } else {
            do {
                let user = try await groupRepository.fetchMemberBy(userId: userId)
                if let user {
                    groupMembers.append(user)
                }
                return user
            } catch {
                currentViewState = .initial
                showToastForError()
                return nil
            }
        }
    }

    // MARK: - User Actions
    func showTransactionDeleteAlert(_ transaction: Transactions) {
        showAlert = true
        alert = .init(title: "Delete Transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: {
                        Task {
                            await self.deleteTransaction(transaction: transaction)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction(transaction: Transactions) async {
        guard let userId = preference.user?.id else { return }
        
        do {
            var deletedTransaction = transaction
            deletedTransaction.updatedBy = userId

            try await transactionRepository.deleteTransaction(groupId: groupId, transaction: deletedTransaction)
            await updateGroupMemberBalance(transaction: deletedTransaction, updateType: .Delete)
            await addLogForDeleteTransaction(transaction: deletedTransaction)
        } catch {
            showToastForError()
        }
    }

    private func addLogForDeleteTransaction(transaction: Transactions) async {
        guard let deletedGroup = group, let user = preference.user else { return }

        var errors: [Error] = []
        let payerName = await fetchUserData(for: transaction.payerId)?.nameWithLastInitial ?? "Someone"
        let receiverName = await fetchUserData(for: transaction.receiverId)?.nameWithLastInitial ?? "Someone"
        let involvedUserIds: Set<String> = [transaction.payerId, transaction.receiverId, transaction.addedBy, transaction.updatedBy]

        await withTaskGroup(of: Void.self) { group in
            for memberId in involvedUserIds {
                group.addTask { [weak self] in
                    guard let self else { return }
                    if let activity = createActivityLogForTransaction(context: ActivityLogContext(group: deletedGroup, transaction: transaction, type: .transactionDeleted, memberId: memberId, currentUser: user, payerName: payerName, receiverName: receiverName)) {
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
            showToastForError()
        }
    }

    private func updateGroupMemberBalance(transaction: Transactions, updateType: TransactionUpdateType) async {
        guard var group else { return }
        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group)
            NotificationCenter.default.post(name: .deleteTransaction, object: transaction)
        } catch {
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
                filteredTransactionsForSelectedTab()
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

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
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

func sortMonthYearStrings(_ s1: String, _ s2: String) -> Bool {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM yyyy"

    guard let date1 = dateFormatter.date(from: s1),
          let date2 = dateFormatter.date(from: s2) else {
        return false
    }

    let components1 = Calendar.current.dateComponents([.year, .month], from: date1)
    let components2 = Calendar.current.dateComponents([.year, .month], from: date2)

    // Compare years first
    if components1.year != components2.year {
        return (components1.year ?? 0) > (components2.year ?? 0)
    }
    // If years are the same, compare months
    else {
        return (components1.month ?? 0) > (components2.month ?? 0)
    }
}
