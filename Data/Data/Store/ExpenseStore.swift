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

    public func addExpense(expense: Expense, completion: @escaping (String?) -> Void) {
        do {
            let code = try database.collection(DATABASE_NAME).addDocument(from: expense)
            completion(code.documentID)
            return
        } catch {
            LogE("ExpenseRepository :: \(#function) error: \(error.localizedDescription)")
        }
        completion(nil)
    }

    public func fetchExpensesBy(groupId: String) -> AnyPublisher<[Expense], ServiceError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(DATABASE_NAME).whereField("group_id", isEqualTo: groupId).getDocuments { snapshot, error in
                if let error = error {
                    LogE("ExpenseRepository :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.networkError))
                    return
                }

                guard let snapshot, !snapshot.documents.isEmpty else {
                    LogD("ExpenseRepository :: \(#function) The document is not available.")
                    promise(.success([]))
                    return
                }

                do {
                    let expenses = try snapshot.documents.compactMap { document in
                        try document.data(as: Expense.self)
                    }
                    promise(.success(expenses))
                } catch {
                    LogE("ExpenseRepository :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    public func deleteExpense(id: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.DATABASE_NAME).document(id).delete { error in
                if let error {
                    LogE("ExpenseRepository :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError))
                } else {
                    LogD("ExpenseRepository :: \(#function): expense deleted successfully.")
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }
}
