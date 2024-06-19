//
//  TransactionListViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 14/06/24.
//

import Data
import SwiftUI

class TransactionListViewModel: BaseViewModel, ObservableObject {

    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var transactionsWithUser: [TransactionWithUser] = []
    @Published private(set) var filteredTransactions: [String: [TransactionWithUser]] = [:]

    @Published var selectedTab: TransactionTabType = .thisMonth
    @Published private(set) var currentViewState: ViewState = .loading

    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private var transactions: [Transactions] = []
    private let groupId: String
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
    }

    // MARK: - Data Loading
    func fetchTransactions() {
        currentViewState = .loading

        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleServiceError(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self = self else { return }
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

        queue.notify(queue: .main) { [self] in
            transactionsWithUser = combinedData
            filteredTransactionsForSelectedTab()
            currentViewState = .initial
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

    private func deleteTransaction(transactionId: String) {
        transactionRepository.deleteTransaction(transactionId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] _ in
                withAnimation { self?.transactionsWithUser.removeAll { $0.transaction.id == transactionId } }
                self?.showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction deleted successfully"))
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func showTransactionDeleteAlert(_ transactionId: String?) {
        guard let transactionId else { return }

        showAlert = true
        alert = .init(title: "Delete transaction",
                      message: "Are you sure you want to delete this transaction?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteTransaction(transactionId: transactionId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
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
            return TransactionListViewModel.dateFormatter.string(from: currentMonth)
        }

        var lastMonth: String {
            let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())
            return TransactionListViewModel.dateFormatter.string(from: lastMonth ?? Date())
        }

        var groupedTransactions: [String: [TransactionWithUser]] {
            return Dictionary(grouping: transactionsWithUser
                .sorted { $0.transaction.date.dateValue() > $1.transaction.date.dateValue() }) { transaction in
                    return TransactionListViewModel.dateFormatter.string(from: transaction.transaction.date.dateValue())
                }
        }

        switch selectedTab {
        case .thisMonth:
            filteredTransactions = groupedTransactions.filter { $0.key == currentMonth }
        case .lastMonth:
            filteredTransactions = groupedTransactions.filter { $0.key == lastMonth }
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
            return components1.year! > components2.year!
        } else {
            return components1.month! > components2.month!
        }
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        currentViewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension TransactionListViewModel {
    enum ViewState: Equatable {
        static func == (lhs: TransactionListViewModel.ViewState, rhs: TransactionListViewModel.ViewState) -> Bool {
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

    case thisMonth, lastMonth, all

    var tabItem: String {
        switch self {
        case .thisMonth:
            return "This month"
        case .lastMonth:
            return "Last month"
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
