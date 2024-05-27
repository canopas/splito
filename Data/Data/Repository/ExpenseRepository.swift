//
//  ExpenseRepository.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import Combine
import FirebaseFirestoreInternal

public class ExpenseRepository: ObservableObject {

    @Inject private var store: ExpenseStore

    private var cancelable = Set<AnyCancellable>()

    public func addExpense(expense: Expense) -> AnyPublisher<Void, ServiceError> {
        store.addExpense(expense: expense)
    }

    public func updateExpense(expense: Expense) -> AnyPublisher<Void, ServiceError> {
        store.updateExpense(expense: expense)
    }

    public func fetchLatestExpensesBy(groupId: String) -> AnyPublisher<[Expense], ServiceError> {
        store.fetchLatestExpensesBy(groupId: groupId)
    }

    public func fetchExpenseBy(expenseId: String) -> AnyPublisher<Expense, ServiceError> {
        store.fetchExpenseBy(expenseId: expenseId)
    }

    public func fetchExpensesBy(groupId: String) -> AnyPublisher<[Expense], ServiceError> {
        store.fetchExpensesBy(groupId: groupId)
    }

    public func deleteExpense(id: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteExpense(id: id)
    }

    public func deleteExpensesOf(groupId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteExpensesOf(groupId: groupId)
    }
}
