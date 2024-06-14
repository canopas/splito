//
//  TransactionListViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 14/06/24.
//

import Data
import Combine
import BaseStyle

class TransactionListViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var transactionRepository: TransactionRepository
    @Inject private var groupRepository: GroupRepository

    private let groupId: String
    private let router: Router<AppRoute>

    @Published var transactionsWithUser: [TransactionWithUser] = []
    @Published var transactions: [Transactions] = []
    @Published var currentViewState: ViewState = .loading

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        self.fetchTransactions()
    }

    // MARK: - Data Loading

    func fetchTransactions() {
        currentViewState = .loading

        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.currentViewState = .initial
                self?.showToastFor(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self = self else { return }
            self.transactions = transactions
            self.calculateTransactions()
        }.store(in: &cancelable)
    }

    private func calculateTransactions() {
           guard let userId = self.preference.user?.id else { return }

           let queue = DispatchGroup()
           var ownAmounts: [String: Double] = [:]
           var combinedData: [TransactionWithUser] = []

           for transaction in transactions {
               queue.enter()

               ownAmounts[transaction.payerId, default: 0.0] += transaction.amount
               ownAmounts[transaction.receiverId, default: 0.0] -= transaction.amount

               self.fetchUserData(for: transaction.payerId) { user in
                   combinedData.append(TransactionWithUser(transaction: transaction, user: user))
                   queue.leave()
               }
           }

           queue.notify(queue: .main) {
               self.transactionsWithUser = combinedData
               self.setTransactionListViewState()
           }
       }

    private func setTransactionListViewState() {
        currentViewState = transactions.isEmpty ? .noTransaction : .hasTransaction(transactions: transactions)
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    func showTransactionDeleteAlert(_ transactionId: String?) {
        showAlert = true
        alert = .init(title: "Delete expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteTransaction(transactionId: transactionId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteTransaction(transactionId: String?) {
        guard let transactionId else { return }

        transactionRepository.deleteTransactionsOf(groupId: transactionId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.showToastFor(toast: .init(type: .success, title: "Success", message: "Transaction deleted successfully"))
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func handleTransactionItemTap(_ transactionId: String?) {
        // Handle transaction item tap
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

// MARK: - Group State
extension TransactionListViewModel {
    enum ViewState: Equatable {
        static func == (lhs: TransactionListViewModel.ViewState, rhs: TransactionListViewModel.ViewState) -> Bool {
            lhs.key == rhs.key
        }

        case loading
        case initial
        case noTransaction
        case hasTransaction(transactions: [Transactions])

        var key: String {
            switch self {
            case .loading:
                return "loading"
            case .initial:
                return "initial"
            case .noTransaction:
                return "noTransaction"
            case .hasTransaction:
                return "hasTransaction"
            }
        }
    }
}

// Struct to hold combined expense and user information
struct TransactionWithUser {
    let transaction: Transactions
    let user: AppUser
}
