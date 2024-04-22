//
//  ExpenseStore.swift
//  Data
//
//  Created by Amisha Italiya on 29/03/24.
//

import Combine
import FirebaseFirestoreInternal

public class ExpenseStore: ObservableObject {

    @Inject private var database: Firestore

    private let DATABASE_NAME: String = "expenses"

    func addExpense(expense: Expense) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                _ = try self.database.collection(self.DATABASE_NAME).addDocument(from: expense)
                promise(.success(()))
            } catch {
                LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateExpense(expense: Expense) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let expenseId = expense.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.database.collection(self.DATABASE_NAME).document(expenseId).setData(from: expense, merge: false)
                promise(.success(()))
            } catch {
                LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }.eraseToAnyPublisher()
    }

    func fetchExpenseBy(expenseId: String) -> AnyPublisher<Expense, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(DATABASE_NAME).document(expenseId).getDocument { snapshot, error in
                if let error {
                    LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
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

    func fetchExpensesBy(groupId: String) -> AnyPublisher<[Expense], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(DATABASE_NAME).whereField("group_id", isEqualTo: groupId).getDocuments { snapshot, error in
                if let error {
                    LogE("ExpenseStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("ExpenseStore :: \(#function) The document is not available.")
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

    func deleteExpense(id: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.DATABASE_NAME).document(id).delete { error in
                if let error {
                    LogE("ExpenseStore :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError))
                } else {
                    LogD("ExpenseStore :: \(#function): expense deleted successfully.")
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }
}
