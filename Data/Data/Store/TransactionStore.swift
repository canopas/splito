//
//  TransactionStore.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import Combine
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

    func addTransaction(groupId: String, transaction: Transactions) async throws -> Transactions {
        let documentRef = self.transactionReference(groupId: groupId).document()

        var newTransaction = transaction
        newTransaction.id = documentRef.documentID

        try documentRef.setData(from: newTransaction)
        return newTransaction
    }

    func updateTransaction(groupId: String, transaction: Transactions) async throws {
        if let transactionId = transaction.id {
            try transactionReference(groupId: groupId).document(transactionId).setData(from: transaction, merge: false)
        } else {
            LogE("TransactionStore :: \(#function) Transaction not found.")
            throw ServiceError.dataNotFound
        }
    }

    func fetchTransactionsBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (transactions: [Transactions], lastDocument: DocumentSnapshot?) {
        var query = transactionReference(groupId: groupId)
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
        return try await transactionReference(groupId: groupId).document(transactionId).getDocument(as: Transactions.self, source: .server)
    }

    func deleteTransaction(groupId: String, transactionId: String) async throws {
        try await transactionReference(groupId: groupId).document(transactionId).delete()
    }

    func deleteTransactionsOf(groupId: String) async throws {
        let snapshot = try await transactionReference(groupId: groupId).getDocuments(source: .server)

        let batch = database.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }

        try await batch.commit()
    }
}
