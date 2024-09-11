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

    func addTransaction(groupId: String, transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                let documentRef = self.transactionReference(groupId: groupId).document()

                var newTransaction = transaction
                newTransaction.id = documentRef.documentID

                try documentRef.setData(from: newTransaction)
                promise(.success(()))
            } catch {
                LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error)))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateTransaction(groupId: String, transaction: Transactions) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let transactionId = transaction.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.transactionReference(groupId: groupId).document(transactionId).setData(from: transaction, merge: false)
                promise(.success(()))
            } catch {
                LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error)))
            }
        }.eraseToAnyPublisher()
    }

    func fetchTransactionsBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) -> AnyPublisher<(transactions: [Transactions], lastDocument: DocumentSnapshot?), ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            var query = self.transactionReference(groupId: groupId)
                .order(by: "date", descending: true)
                .limit(to: limit)

            if let lastDocument {
                query = query.start(afterDocument: lastDocument)
            }

            query.getDocuments(source: .server) { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error)))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("TransactionStore :: \(#function) The document is not available.")
                    promise(.success(([], nil)))
                    return
                }

                do {
                    let transactions = try snapshot.documents.compactMap { document in
                        try document.data(as: Transactions.self)
                    }
                    promise(.success((transactions, snapshot.documents.last)))
                } catch {
                    LogE("TransactionStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchTransactionsBy(groupId: String, transactionId: String) -> AnyPublisher<Transactions, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.transactionReference(groupId: groupId).document(transactionId).getDocument(source: .server) { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error)))
                    return
                }

                guard let snapshot else {
                    LogE("TransactionStore :: \(#function) The document is not available.")
                    promise(.failure(.dataNotFound))
                    return
                }

                do {
                    let transaction = try snapshot.data(as: Transactions.self)
                    promise(.success(transaction))
                } catch {
                    LogE("TransactionStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func deleteTransaction(groupId: String, transactionId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.transactionReference(groupId: groupId).document(transactionId).delete { error in
                if let error {
                    LogE("TransactionStore :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError(error: error)))
                } else {
                    LogD("TransactionStore :: \(#function): transaction deleted successfully.")
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }

    func deleteTransactionsOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.transactionReference(groupId: groupId).getDocuments(source: .server) { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error)))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("TransactionStore :: \(#function) The document is not available.")
                    promise(.success(()))
                    return
                }

                let batch = self.database.batch()
                snapshot.documents.forEach { batch.deleteDocument($0.reference) }

                batch.commit { error in
                    if let error {
                        promise(.failure(.databaseError(error: error)))
                        LogE("TransactionStore :: \(#function) Database error: \(error.localizedDescription)")
                    } else {
                        promise(.success(()))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
