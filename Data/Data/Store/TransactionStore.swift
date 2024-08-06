//
//  TransactionStore.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import Combine
import FirebaseFirestoreInternal

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
                promise(.failure(.databaseError(error: error.localizedDescription)))
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
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }.eraseToAnyPublisher()
    }

    func fetchLatestTransactionsBy(groupId: String) -> AnyPublisher<[Transactions], ServiceError> {
        transactionReference(groupId: groupId)
            .limit(to: 20)
            .snapshotPublisher(as: Transactions.self)
    }

    func fetchTransactionsBy(userId: String) -> AnyPublisher<[Transactions], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(SUB_COLLECTION_NAME).whereField("payer_id", isEqualTo: userId).getDocuments { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot else {
                    LogE("TransactionStore :: \(#function) The document is not available.")
                    promise(.failure(.dataNotFound))
                    return
                }

                do {
                    let transactions = try snapshot.documents.compactMap { document in
                        try document.data(as: Transactions.self)
                    }
                    promise(.success(transactions))
                } catch {
                    LogE("TransactionStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func fetchTransactionsBy(groupId: String) -> AnyPublisher<[Transactions], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.transactionReference(groupId: groupId).addSnapshotListener { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("TransactionStore :: \(#function) The document is not available.")
                    promise(.success([]))
                    return
                }

                do {
                    let transactions = try snapshot.documents.compactMap { document in
                        try document.data(as: Transactions.self)
                    }
                    promise(.success(transactions))
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

            self.transactionReference(groupId: groupId).document(transactionId).getDocument { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
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
                    promise(.failure(.databaseError(error: error.localizedDescription)))
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

            self.transactionReference(groupId: groupId).getDocuments { snapshot, error in
                if let error {
                    LogE("TransactionStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
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
                        promise(.failure(.databaseError(error: error.localizedDescription)))
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
