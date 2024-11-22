//
//  ExpenseRepository.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public class ExpenseRepository: ObservableObject {

    @Inject private var store: ExpenseStore
    @Inject private var preference: SplitoPreference
    @Inject private var activityLogRepository: ActivityLogRepository

    public func addExpense(group: Groups, expense: Expense) async throws -> Expense {
        let newExpense = try await store.addExpense(groupId: group.id ?? "", expense: expense)
        try await addActivityLogForExpense(group: group, expense: newExpense, oldExpense: newExpense, type: .expenseAdded)
        return newExpense
    }

    public func deleteExpense(group: Groups, expense: Expense) async throws {
        guard let userId = preference.user?.id else { return }

        var updatedExpense = expense
        updatedExpense.isActive = false  // Make expense inactive
        updatedExpense.updatedBy = userId
        try await updateExpense(group: group, expense: updatedExpense, oldExpense: expense, type: .expenseDeleted)
    }

    public func updateExpense(group: Groups, expense: Expense, oldExpense: Expense, type: ActivityType) async throws {
        guard let groupId = group.id else { return }
        try await store.updateExpense(groupId: groupId, expense: expense)
        try await addActivityLogForExpense(group: group, expense: expense, oldExpense: oldExpense, type: type)
    }

    private func addActivityLogForExpense(group: Groups, expense: Expense, oldExpense: Expense, type: ActivityType) async throws {
        guard let user = preference.user, type != .none else { return }

        let involvedUserIds = getInvolvedUserIds(oldExpense: oldExpense, expense: expense, user: user)
        let context = ActivityLogContext(group: group, expense: expense, type: type, currentUser: user)
        try await addActivityLogsInParallel(for: involvedUserIds, context: context)
    }

    private func getInvolvedUserIds(oldExpense: Expense, expense: Expense, user: AppUser) -> Set<String> {
        Set(oldExpense.splitTo + Array(oldExpense.paidBy.keys) + expense.splitTo + Array(expense.paidBy.keys) +
            [user.id, expense.addedBy, expense.updatedBy])
    }

    private func addActivityLogsInParallel(for userIds: Set<String>, context: ActivityLogContext) async throws {
        var throwableError: Error?

        await withTaskGroup(of: Error?.self) { taskGroup in
            for memberId in userIds {
                taskGroup.addTask { [weak self] in
                    guard let self else { return nil }
                    var context = context
                    context.memberId = memberId
                    return await self.addActivityLog(context: context)
                }
            }

            for await error in taskGroup {
                if let error {
                    throwableError = error
                    taskGroup.cancelAll()
                    break
                }
            }
        }

        if let throwableError {
            throw throwableError
        }
    }

    private func createActivityLogForExpense(context: ActivityLogContext) -> ActivityLog? {
        guard let group = context.group, let groupId = group.id, let expense = context.expense,
              let expenseId = expense.id, let currentUser = context.currentUser,
              let memberId = context.memberId else { return nil }

        let amount = expense.getCalculatedSplitAmountOf(member: memberId)
        let actionUserName = (memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial

        return ActivityLog(type: context.type, groupId: groupId, activityId: expenseId, groupName: group.name,
                           actionUserName: actionUserName, recordedOn: Timestamp(date: Date()),
                           expenseName: expense.name, amount: amount)
    }

    private func addActivityLog(context: ActivityLogContext) async -> Error? {
        if let activity = createActivityLogForExpense(context: context), let memberId = context.memberId {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
            } catch {
                return error
            }
        }
        return nil
    }

    public func fetchExpensesBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (expenses: [Expense], lastDocument: DocumentSnapshot?) {
        return try await store.fetchExpensesBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchExpenseBy(groupId: String, expenseId: String) async throws -> Expense {
        return try await store.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
    }
}
