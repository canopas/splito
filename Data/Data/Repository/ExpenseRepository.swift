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

    public func deleteExpense(id: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteExpense(id: id)
    }
}
