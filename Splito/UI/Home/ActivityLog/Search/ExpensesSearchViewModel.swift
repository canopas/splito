//
//  ExpensesSearchViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 30/12/24.
//

import Data
import SwiftUI
import FirebaseFirestore

class ExpensesSearchViewModel: BaseViewModel, ObservableObject {

    private let EXPENSES_LIMIT = 10

    @Inject private var preference: SplitoPreference
    @Inject var expenseRepository: ExpenseRepository
    @Inject private var groupRepository: GroupRepository

    @Published var expenses: [Expense] = []
    @Published var expensesWithUser: [ExpenseWithUser] = []
    @Published var viewState: ViewState = .loading
    @Published var groupExpenses: [String: [ExpenseWithUser]] = [:]
    @Published private(set) var hasMoreExpenses: Bool = true

    @Published var searchedExpense: String = "" {
        didSet {
            updateGroupExpenses()
        }
    }

    var isExpensesLoading = false
    private var activeGroupIds: [String] = []
    private var groupMembers: [AppUser] = []
    private let router: Router<AppRoute>
    private var lastDocument: DocumentSnapshot?

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateExpense(notification:)), name: .updateExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeleteExpense(notification:)), name: .deleteExpense, object: nil)

        fetchInitialExpenses()
    }

    func fetchInitialExpenses() {
        lastDocument = nil
        Task {
            await fetchAllActiveGroups()
            await fetchExpensesOfAllGroups()
        }
    }

    // MARK: - Data Loading
    private func fetchAllActiveGroups() async {
        guard let userId = preference.user?.id else {
            viewState = .noExpense
            return
        }
        do {
            let groups = try await groupRepository.fetchUsersActiveGroups(userId: userId)
            activeGroupIds = groups.compactMap { $0.id }
        } catch {
            LogE("ExpensesSearchViewModel: \(#function) failed with error: \(error).")
            handleServiceError()
        }
    }

    func loadMoreExpenses() {
        guard hasMoreExpenses, !isExpensesLoading else { return }
        Task { [weak self] in
            self?.isExpensesLoading = true
            await self?.fetchExpensesOfAllGroups()
        }
    }

    private func fetchExpensesOfAllGroups() async {
        guard let userId = preference.user?.id else {
            viewState = .noExpense
            return
        }

        if lastDocument == nil {
            expensesWithUser = []
        }

        do {
            let result = try await expenseRepository.fetchExpensesOfAllGroups(userId: userId,
                                                                              activeGroupIds: activeGroupIds,
                                                                              limit: EXPENSES_LIMIT,
                                                                              lastDocument: lastDocument)
            expenses = lastDocument == nil ? result.expenses.uniqued() : (expenses + result.expenses.uniqued())
            lastDocument = result.lastDocument

            await combineMemberWithExpense(expenses: result.expenses.uniqued())
            hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
            isExpensesLoading = false
            LogD("ExpensesSearchViewModel: \(#function) Expenses fetched successfully.")
        } catch {
            LogE("ExpensesSearchViewModel: \(#function) failed with error: \(error).")
            handleServiceError()
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
                LogD("ExpensesSearchViewModel: \(#function) Fetched Member is already exists.")
                return fetchedMember
            }
            let member = try await groupRepository.fetchMemberBy(memberId: memberId)
            if let member {
                groupMembers.append(member)
                LogD("ExpensesSearchViewModel: \(#function) Member fetched successfully.")
            }
            return member
        } catch {
            viewState = .noExpense
            LogE("ExpensesSearchViewModel: \(#function) Failed to fetch member \(memberId): \(error).")
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
        withAnimation(.easeOut) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.viewState = self.expenses.isEmpty ? .noExpense : .hasExpense
            }
        }
    }

    // MARK: - User Actions
    func handleExpenseItemTap(expense: Expense) {
        if let expenseId = expense.id {
            router.push(.ExpenseDetailView(groupId: expense.groupId, expenseId: expenseId))
        }
    }

    @objc func handleUpdateExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }

        if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
            expenses[index] = updatedExpense
        }

        Task { [weak self] in
            if let user = await self?.fetchMemberData(for: updatedExpense.paidBy.keys.first ?? "") {
                if let index = self?.expensesWithUser.firstIndex(where: { $0.expense.id == updatedExpense.id }) {
                    let updatedExpenseWithUser = ExpenseWithUser(expense: updatedExpense, user: user)
                    withAnimation {
                        self?.expensesWithUser[index] = updatedExpenseWithUser
                        self?.updateGroupExpenses()
                    }
                }
            }
        }
    }

    @objc func handleDeleteExpense(notification: Notification) {
        guard let deletedExpense = notification.object as? Expense else { return }
        expenses.removeAll { $0.id == deletedExpense.id }
        if let index = expensesWithUser.firstIndex(where: { $0.expense.id == deletedExpense.id }) {
            withAnimation { [weak self] in
                self?.expensesWithUser.remove(at: index)
                self?.updateGroupExpenses()
                self?.showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully."))
            }
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        isExpensesLoading = false
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
extension ExpensesSearchViewModel {
    enum ViewState {
        case noExpense
        case hasExpense
        case loading
        case noInternet
        case somethingWentWrong
    }
}
