//
//  TransactionStore.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import FirebaseFirestore

public class TransactionStore: ObservableObject {

    @Inject private var database: Firestore

    private let COLLECTION_NAME: String = "groups"
    private let SUB_COLLECTION_NAME: String = "transactions"

    private func transactionReference(groupId: String) -> CollectionReference {
        database
            .collection(COLLECTION_NAME)
            .document(groupId)
            .collection(SUB_COLLECTION_NAME)
    }

    func getNewTransactionDocument(groupId: String) async throws -> DocumentReference {
        return transactionReference(groupId: groupId).document()
    }

    func addTransaction(document: DocumentReference, transaction: Transactions) async throws {
        try document.setData(from: transaction)
    }

    func updateTransaction(groupId: String, transaction: Transactions) async throws {
        if let transactionId = transaction.id {
            try transactionReference(groupId: groupId).document(transactionId).setData(from: transaction, merge: false)
        } else {
            LogE("TransactionStore: \(#function) Payment not found.")
            throw ServiceError.dataNotFound
        }
    }

    func fetchTransactionsBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (transactions: [Transactions], lastDocument: DocumentSnapshot?) {
        var query = transactionReference(groupId: groupId)
            .whereField("is_active", isEqualTo: true)
            .order(by: "date", descending: true)
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        let snapshot = try await query.getDocuments(source: .server)
        let transactions = try snapshot.documents.compactMap { document in
            try document.data(as: Transactions.self)
        }

        return (transactions, snapshot.documents.last)
    }

    func fetchTransactionsBy(groupId: String, transactionId: String) async throws -> Transactions {
        try await transactionReference(groupId: groupId)
            .document(transactionId)
            .getDocument(as: Transactions.self, source: .server)
    }

    func getTransactionsCount(groupId: String) async throws -> Int {
        let count = try await transactionReference(groupId: groupId)
            .whereField("is_active", isEqualTo: true)
            .count.getAggregation(source: .server).count
        return Int(truncating: count)
    }
}
