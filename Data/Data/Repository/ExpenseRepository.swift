//
//  ExpenseRepository.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import Combine
import FirebaseFirestore

public class ExpenseRepository: ObservableObject {

    @Inject private var store: ExpenseStore

    private var cancelable = Set<AnyCancellable>()

    public func addExpense(groupId: String, expense: Expense) -> AnyPublisher<Void, ServiceError> {
        store.addExpense(groupId: groupId, expense: expense)
    }

    public func updateExpense(groupId: String, expense: Expense) -> AnyPublisher<Void, ServiceError> {
        store.updateExpense(groupId: groupId, expense: expense)
    }

    public func fetchExpensesBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) -> AnyPublisher<(expenses: [Expense], lastDocument: DocumentSnapshot?), ServiceError> {
        store.fetchExpensesBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchExpenseBy(groupId: String, expenseId: String) -> AnyPublisher<Expense, ServiceError> {
        store.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
    }

    public func deleteExpense(groupId: String, expenseId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteExpense(groupId: groupId, expenseId: expenseId)
    }

    public func deleteExpensesOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteExpensesOf(groupId: groupId)
    }

    public func fetchCurrentMonthExpensesBy(groupId: String) -> AnyPublisher<[Expense], ServiceError> {
        store.fetchCurrentMonthExpensesBy(groupId: groupId)
    }
}
