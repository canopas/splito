//
//  ExpenseStore.swift
//  Data
//
//  Created by Amisha Italiya on 29/03/24.
//

import Combine
import FirebaseFirestore

public class ExpenseStore: ObservableObject {

    @Inject private var database: Firestore

    private let COLLECTION_NAME: String = "groups"
    private let SUB_COLLECTION_NAME: String = "expenses"

    private func expenseReference(groupId: String) -> CollectionReference {
        database
            .collection(COLLECTION_NAME)
            .document(groupId)
            .collection(SUB_COLLECTION_NAME)
    }

    func addExpense(groupId: String, expense: Expense) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                let documentRef = self.expenseReference(groupId: groupId).document()

                var newExpense = expense
                newExpense.id = documentRef.documentID

                try documentRef.setData(from: newExpense)
                promise(.success(()))
            } catch {
                LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateExpense(groupId: String, expense: Expense) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let expenseId = expense.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.expenseReference(groupId: groupId).document(expenseId).setData(from: expense, merge: false)
                promise(.success(()))
            } catch {
                LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }.eraseToAnyPublisher()
    }

    func fetchExpenseBy(groupId: String, expenseId: String) -> AnyPublisher<Expense, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.expenseReference(groupId: groupId).document(expenseId).getDocument { snapshot, error in
                if let error {
                    LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot else {
                    LogE("ExpenseStore :: \(#function) The document is not available.")
                    promise(.failure(.dataNotFound))
                    return
                }

                do {
                    let expense = try snapshot.data(as: Expense.self)
                    promise(.success(expense))
                } catch {
                    LogE("ExpenseStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func fetchExpensesBy(groupId: String, limit: Int, lastDocument: DocumentSnapshot?) -> AnyPublisher<(expenses: [Expense], lastDocument: DocumentSnapshot?), ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            var query = self.expenseReference(groupId: groupId)
                .order(by: "date", descending: true)
                .limit(to: limit)

            if let lastDocument {
                query = query.start(afterDocument: lastDocument)
            }

            query.getDocuments { snapshot, error in
                if let error {
                    LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("ExpenseStore :: \(#function) The document is not available.")
                    promise(.success(([], nil)))
                    return
                }

                do {
                    let expenses = try snapshot.documents.compactMap { document in
                        try document.data(as: Expense.self)
                    }
                    promise(.success((expenses, snapshot.documents.last)))
                } catch {
                    LogE("ExpenseStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteExpense(groupId: String, expenseId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.expenseReference(groupId: groupId).document(expenseId).delete { error in
                if let error {
                    LogE("ExpenseStore :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                } else {
                    LogD("ExpenseStore :: \(#function): expense deleted successfully.")
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteExpensesOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.expenseReference(groupId: groupId).getDocuments { snapshot, error in
                if let error {
                    LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("ExpenseStore :: \(#function) The document is not available.")
                    promise(.success(()))
                    return
                }

                let batch = self.database.batch()
                snapshot.documents.forEach { batch.deleteDocument($0.reference) }

                batch.commit { error in
                    if let error {
                        promise(.failure(.databaseError(error: error.localizedDescription)))
                        LogE("ExpenseStore :: \(#function) Database error: \(error.localizedDescription)")
                    } else {
                        promise(.success(()))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchCurrentMonthExpensesBy(groupId: String) -> AnyPublisher<[Expense], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            let startOfMonth = Date().startOfMonth()
            let endOfMonth = Date().endOfMonth()

            self.expenseReference(groupId: groupId)
                .whereField("date", isGreaterThanOrEqualTo: startOfMonth)
                .whereField("date", isLessThanOrEqualTo: endOfMonth)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                        promise(.failure(.databaseError(error: error.localizedDescription)))
                        return
                    }

                    guard let snapshot, !snapshot.documents.isEmpty else {
                        LogD("ExpenseStore :: \(#function) No expenses found for the current month.")
                        promise(.success([]))
                        return
                    }

                    do {
                        let expenses = try snapshot.documents.compactMap { document in
                            try document.data(as: Expense.self)
                        }
                        promise(.success(expenses))
                    } catch {
                        LogE("ExpenseStore :: \(#function) Decode error: \(error.localizedDescription)")
                        promise(.failure(.decodingError))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
}
