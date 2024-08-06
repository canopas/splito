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

    public func addTransaction(groupId: String, transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        store.addTransaction(groupId: groupId, transaction: transaction)
    }

    public func updateTransaction(groupId: String, transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        store.updateTransaction(groupId: groupId, transaction: transaction)
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

    public func fetchTransactionBy(groupId: String, transactionId: String) -> AnyPublisher<Transactions, ServiceError> {
        store.fetchTransactionsBy(groupId: groupId, transactionId: transactionId)
    }

    public func deleteTransaction(groupId: String, transactionId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteTransaction(groupId: groupId, transactionId: transactionId)
    }

    public func deleteTransactionsOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteTransactionsOf(groupId: groupId)
    }
}
