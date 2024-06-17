//
//  TransactionRepository.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import Combine
import FirebaseFirestoreInternal

public class TransactionRepository: ObservableObject {

    @Inject private var store: TransactionStore

    public func addTransaction(transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        store.addTransaction(transaction: transaction)
    }

    public func updateTransaction(transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        store.updateTransaction(transaction: transaction)
    }

    public func fetchLatestTransactionsBy(groupId: String) -> AnyPublisher<[Transactions], ServiceError> {
        store.fetchLatestTransactionsBy(groupId: groupId)
    }

    public func fetchTransactionsBy(userId: String) -> AnyPublisher<[Transactions], ServiceError> {
        store.fetchTransactionsBy(userId: userId)
    }

    public func fetchTransactionsBy(groupId: String) -> AnyPublisher<[Transactions], ServiceError> {
        store.fetchTransactionsBy(groupId: groupId)
    }

    public func fetchTransactionBy(transactionId: String) -> AnyPublisher<Transactions, ServiceError> {
        store.fetchTransactionsBy(transactionId: transactionId)
    }

    public func deleteTransaction(transactionId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteTransaction(transactionId: transactionId)
    }

    public func deleteTransactionsOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteTransactionsOf(groupId: groupId)
    }
}
