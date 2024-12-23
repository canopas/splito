//
//  ExpenseStore.swift
//  Data
//
//  Created by Amisha Italiya on 29/03/24.
//

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

    func getNewExpenseDocument(groupId: String) async throws -> DocumentReference {
        return expenseReference(groupId: groupId).document()
    }

    func addExpense(document: DocumentReference, expense: Expense) async throws {
        try document.setData(from: expense)
    }

    func updateExpense(groupId: String, expense: Expense) async throws {
        if let expenseId = expense.id {
            try expenseReference(groupId: groupId).document(expenseId).setData(from: expense, merge: false)
        } else {
            LogE("ExpenseStore: \(#function) Expense not found.")
            throw ServiceError.dataNotFound
        }
    }

    func fetchExpenseBy(groupId: String, expenseId: String) async throws -> Expense {
        return try await expenseReference(groupId: groupId).document(expenseId).getDocument(as: Expense.self, source: .server)
    }

    func fetchExpensesBy(groupId: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> (expenses: [Expense], lastDocument: DocumentSnapshot?) {
        var query = expenseReference(groupId: groupId)
            .whereField("is_active", isEqualTo: true)
            .order(by: "date", descending: true)
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        let snapshot = try await query.getDocuments(source: .server)
        let expenses = try snapshot.documents.compactMap { document in
            try document.data(as: Expense.self)
        }

        return (expenses, snapshot.documents.last)
    }
}
