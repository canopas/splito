//
//  GroupTransactionListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/06/24.
//

import Data
import SwiftUI

class GroupTransactionListViewModel: BaseViewModel, ObservableObject {

    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var transactionsWithUser: [TransactionWithUser] = []
    @Published private(set) var filteredTransactions: [String: [TransactionWithUser]] = [:]

    @Published private var transactions: [Transactions] = []
    @Published var selectedTab: TransactionTabType = .thisMonth
    @Published private(set) var currentViewState: ViewState = .loading

    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private let groupId: String
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        fetchLatestTransactions()
    }

    // MARK: - Data Loading
    func fetchTransactions() {
        currentViewState = .loading

        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleServiceError(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self else { return }
            self.transactions = transactions
            self.combinedTransactionsWithUser()
        }.store(in: &cancelable)
    }

    private func fetchLatestTransactions() {
        transactionRepository.fetchLatestTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleServiceError(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self else { return }
            self.transactions = transactions
            self.combinedTransactionsWithUser()
        }.store(in: &cancelable)
    }

    private func combinedTransactionsWithUser() {
        let queue = DispatchGroup()
        var combinedData: [TransactionWithUser] = []

        for transaction in transactions {
            queue.enter()
            self.fetchUserData(for: transaction.payerId) { payer in
                self.fetchUserData(for: transaction.receiverId) { receiver in
                    combinedData.append(TransactionWithUser(transaction: transaction, payer: payer, receiver: receiver))
                    queue.leave()
                }
            }
        }

        queue.notify(queue: .main) { [weak self] in
            guard let self else { return }
            withAnimation {
                self.transactionsWithUser = combinedData
                self.filteredTransactionsForSelectedTab()
                self.currentViewState = .initial
            }
        }
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func showTransactionDeleteAlert(_ transactionId: String?) {
        guard let transactionId else { return }

        showAlert = true
        alert = .init(title: "Delete Transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteTransaction(transactionId: transactionId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction(transactionId: String) {
        transactionRepository.deleteTransaction(groupId: groupId, transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                guard let self else { return }
                withAnimation {
                    if let index = self.transactions.firstIndex(where: { $0.id == transactionId }) {
                        self.transactions.remove(at: index)
                    }
                }
                self.showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction deleted successfully"))
            }.store(in: &cancelable)
    }

    func handleTransactionItemTap(_ transactionId: String?) {
        guard let transactionId else { return }
        router.push(.TransactionDetailView(transactionId: transactionId, groupId: groupId))
    }

    func handleTabItemSelection(_ selection: TransactionTabType) {
        withAnimation(.easeInOut(duration: 0.3), {
            selectedTab = selection
            filteredTransactionsForSelectedTab()
        })
    }

    private func filteredTransactionsForSelectedTab() {
        var currentMonth: String {
            let currentMonth = Date()
            return GroupTransactionListViewModel.dateFormatter.string(from: currentMonth)
        }

        var currentYear: Int {
            let currentDate = Date()
            return Calendar.current.component(.year, from: currentDate)
        }

        var groupedTransactions: [String: [TransactionWithUser]] {
            return Dictionary(grouping: transactionsWithUser
                .sorted { $0.transaction.date.dateValue() > $1.transaction.date.dateValue() }) { transaction in
                    return GroupTransactionListViewModel.dateFormatter.string(from: transaction.transaction.date.dateValue())
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

    // MARK: - Helper Methods
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

enum TransactionTabType: Int, CaseIterable {

    case thisMonth, thisYear, all

    var tabItem: String {
        switch self {
        case .thisMonth:
            return "This month"
        case .thisYear:
            return "This year"
        case .all:
            return "All"
        }
    }
}

// Struct to hold combined transaction and user information
struct TransactionWithUser {
    let transaction: Transactions
    let payer: AppUser?
    let receiver: AppUser?
}
