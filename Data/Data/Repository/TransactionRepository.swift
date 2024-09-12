//
//  TransactionRepository.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import Combine
import FirebaseFirestore

public class TransactionRepository: ObservableObject {

    @Inject private var store: TransactionStore

    public func addTransaction(groupId: String, transaction: Transactions) async throws -> Transactions {
        try await store.addTransaction(groupId: groupId, transaction: transaction)
    }

    public func updateTransaction(groupId: String, transaction: Transactions) async throws {
        try await store.updateTransaction(groupId: groupId, transaction: transaction)
    }

    public func fetchTransactionsBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (transactions: [Transactions], lastDocument: DocumentSnapshot?) {
        try await store.fetchTransactionsBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchTransactionBy(groupId: String, transactionId: String) async throws -> Transactions {
        try await store.fetchTransactionsBy(groupId: groupId, transactionId: transactionId)
    }

    public func deleteTransaction(groupId: String, transactionId: String) async throws {
        try await store.deleteTransaction(groupId: groupId, transactionId: transactionId)
    }

    public func deleteTransactionsOf(groupId: String) async throws {
        try await store.deleteTransactionsOf(groupId: groupId)
    }
}
