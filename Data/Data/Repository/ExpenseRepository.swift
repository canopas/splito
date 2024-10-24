//
//  ExpenseRepository.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public class ExpenseRepository: ObservableObject {

    @Inject private var store: ExpenseStore

    public func addExpense(groupId: String, expense: Expense) async throws -> Expense {
        return try await store.addExpense(groupId: groupId, expense: expense)
    }

    public func updateExpense(groupId: String, expense: Expense) async throws {
        try await store.updateExpense(groupId: groupId, expense: expense)
    }

    public func fetchExpensesBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (expenses: [Expense], lastDocument: DocumentSnapshot?) {
        return try await store.fetchExpensesBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchExpenseBy(groupId: String, expenseId: String) async throws -> Expense {
        return try await store.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
    }

    public func deleteExpense(groupId: String, expense: Expense) async throws {
        var expense = expense
        expense.isActive = false  // Make expense inactive

        try await updateExpense(groupId: groupId, expense: expense)
    }
}
