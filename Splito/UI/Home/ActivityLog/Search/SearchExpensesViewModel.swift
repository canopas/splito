//
//  SearchExpensesViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 30/12/24.
//

import Data
import SwiftUI
import Foundation
import FirebaseFirestore

class SearchExpensesViewModel: BaseViewModel, ObservableObject {

    private let EXPENSES_LIMIT = 10

    @Published private(set) var viewState: ViewState = .loading

    @Inject private var preference: SplitoPreference
    @Inject var expenseRepository: ExpenseRepository
    @Inject private var groupRepository: GroupRepository

    @Published private(set) var hasMoreExpenses: Bool = true

    @Published var expenses: [Expense] = []
    @Published var expensesWithUser: [ExpenseWithUser] = []
    @Published private(set) var groupExpenses: [String: [ExpenseWithUser]] = [:]

    @Published var searchedExpense: String = "" {
        didSet {
            updateGroupExpenses()
        }
    }

    private var groupMembers: [AppUser] = []
    private let router: Router<AppRoute>
    private var lastDocument: DocumentSnapshot?

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        fetchInitialExpenses()
    }

    func fetchInitialExpenses() {
        lastDocument = nil
        Task {
            await fetchAllUserExpenses()
        }
    }

    // MARK: - Data Loading
    private func fetchAllUserExpenses() async {
        guard let userId = preference.user?.id, hasMoreExpenses else {
            viewState = .noExpense
            return
        }

        if lastDocument == nil {
            expensesWithUser = []
        }

        do {
            let result = try await expenseRepository.fetchExpensesForUser(userId: userId, limit: EXPENSES_LIMIT, lastDocument: lastDocument)
            self.expenses = lastDocument == nil ? result.expenses.uniqued() : (expenses + result.expenses.uniqued())
            lastDocument = result.lastDocument

            await combineMemberWithExpense(expenses: result.expenses.uniqued())
            hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
            LogD("SearchExpensesViewModel: \(#function) Expenses fetched successfully.")
        } catch {
            LogE("SearchExpensesViewModel: \(#function) Failed to fetch expenses: \(error).")
            handleServiceError()
        }
    }

    func loadMoreExpenses() {
        Task {
            await fetchAllUserExpenses()
        }
    }

    private func combineMemberWithExpense(expenses: [Expense]) async {
        var combinedData: [ExpenseWithUser] = []

        await withTaskGroup(of: ExpenseWithUser?.self) { taskGroup in
            for expense in expenses.uniqued() {
                taskGroup.addTask { [weak self] in
                    guard let self else { return nil }
                    if let user = await self.fetchMemberData(for: expense.paidBy.keys.first ?? "") {
                        return ExpenseWithUser(expense: expense, user: user)
                    }
                    return nil
                }
            }

            for await result in taskGroup {
                if let expenseWithUser = result {
                    combinedData.append(expenseWithUser)
                }
            }
        }

        withAnimation(.easeOut) {
            expensesWithUser.append(contentsOf: combinedData.uniqued())
            updateGroupExpenses()
            fetchGroupBalance()
        }
    }

    func fetchMemberData(for memberId: String) async -> AppUser? {
        do {
            let fetchedMember = getMemberDataBy(id: memberId)
            guard fetchedMember == nil else {
                LogD("SearchExpensesViewModel: \(#function) Fetched Member is already exists.")
                return fetchedMember
            }
            let member = try await groupRepository.fetchMemberBy(memberId: memberId)
            if let member {
                groupMembers.append(member)
                LogD("SearchExpensesViewModel: \(#function) Member fetched successfully.")
            }
            return member
        } catch {
            viewState = .noExpense
            LogE("SearchExpensesViewModel: \(#function) Failed to fetch member \(memberId): \(error).")
            showToastForError()
            return nil
        }
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return groupMembers.first(where: { $0.id == id })
    }

    func updateGroupExpenses() {
        let filteredExpenses = expensesWithUser.uniqued().filter { expense in
            searchedExpense.isEmpty ||
            expense.expense.name.lowercased().contains(searchedExpense.lowercased()) ||
            expense.expense.amount == Double(searchedExpense)
        }
        groupExpenses = Dictionary(grouping: filteredExpenses.uniqued().sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
            return expense.expense.date.dateValue().monthWithYear
        }
    }

    func fetchGroupBalance() {
        withAnimation(.easeOut) {
            viewState = expenses.isEmpty ? .noExpense : .hasExpense
        }
    }

    // MARK: - User Actions
    func handleExpenseItemTap(expenseId: String) {
        //        router.push(.ExpenseDetailView(groupId: groupId, expenseId: expenseId))
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if lastDocument == nil {
            if !networkMonitor.isConnected {
                viewState = .noInternet
            } else {
                viewState = .somethingWentWrong
            }
        } else {
            viewState = .noExpense
            showToastForError()
        }
    }
}

// MARK: - Group States
extension SearchExpensesViewModel {
    enum ViewState {
        case noExpense
        case hasExpense
        case loading
        case noInternet
        case somethingWentWrong
    }
}
