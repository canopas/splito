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

    func fetchExpensesOfAllGroups(userId: String, activeGroupIds: [String], limit: Int,
                                  lastDocument: DocumentSnapshot?) async throws -> (expenses: [Expense], lastDocument: DocumentSnapshot?) {

        var allExpenses: [Expense] = []
        var remainingLimit = limit
        var lastDocumentId = lastDocument

        // Split the activeGroupIds into chunks of 10
        let chunks = activeGroupIds.chunked(into: 10)

        for chunk in chunks {
            if remainingLimit == 0 { break }

            var query = database.collectionGroup(SUB_COLLECTION_NAME)
                .whereField("group_id", in: chunk)
                .whereField("is_active", isEqualTo: true)
                .whereField("participants", arrayContains: userId)
                .order(by: "date", descending: true)
                .limit(to: remainingLimit)

            if let lastDocumentId {
                query = query.start(afterDocument: lastDocumentId)
            }

            let snapshot = try await query.getDocuments(source: .server)
            lastDocumentId = snapshot.documents.last
            remainingLimit -= snapshot.documents.count

            do {
                let expenses = try snapshot.documents.map { try $0.data(as: Expense.self) }
                allExpenses.append(contentsOf: expenses)
            } catch {
                LogE("ExpenseStore: \(#function) Error decoding expense: \(error.localizedDescription)")
                break
            }
        }

        return (allExpenses, lastDocumentId)
    }
}
