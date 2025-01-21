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
    @Inject private var storageManager: StorageManager
    @Inject private var activityLogRepository: ActivityLogRepository

    public func addExpense(group: Groups, expense: Expense, imageData: Data?) async throws -> Expense {
        // Generate a new document ID for the expense
        let groupId = group.id ?? ""
        let expenseDocument = try await store.getNewExpenseDocument(groupId: groupId)

        var newExpense = expense
        newExpense.id = expenseDocument.documentID

        // If image data is provided, upload the image and update the expense's imageUrl
        if let imageData {
            let imageUrl = try await uploadImage(imageData: imageData, expense: newExpense)
            newExpense.imageUrl = imageUrl
        }

        try await store.addExpense(document: expenseDocument, expense: newExpense)
        try await addActivityLogForExpense(group: group, expense: newExpense, oldExpense: newExpense, type: .expenseAdded)
        return newExpense
    }

    public func deleteExpense(group: Groups, expense: Expense) async throws -> Expense {
        var updatedExpense = expense
        updatedExpense.isActive = false  // Make expense inactive
        updatedExpense.updatedBy = preference.user?.id ?? ""
        updatedExpense.updatedAt = Timestamp()
        return try await updateExpense(group: group, expense: updatedExpense, oldExpense: expense, type: .expenseDeleted)
    }

    public func updateExpenseWithImage(imageData: Data?, newImageUrl: String?, group: Groups,
                                       expense: (new: Expense, old: Expense), type: ActivityType) async throws -> Expense {
        var updatedExpense = expense.new

        // If image data is provided, upload the new image and update the imageUrl
        if let imageData {
            let uploadedImageUrl = try await uploadImage(imageData: imageData, expense: updatedExpense)
            updatedExpense.imageUrl = uploadedImageUrl
        } else if let currentUrl = updatedExpense.imageUrl, newImageUrl == nil {
            // If there's a current image URL and we want to remove it, delete the image and set imageUrl empty
            try await storageManager.deleteAttachment(attachmentUrl: currentUrl)
            updatedExpense.imageUrl = ""
        } else if let newImageUrl {
            // If a new image URL is explicitly passed, update it
            updatedExpense.imageUrl = newImageUrl
        }

        guard hasExpenseChanged(updatedExpense, oldExpense: expense.old) else { return updatedExpense }
        return try await updateExpense(group: group, expense: updatedExpense, oldExpense: expense.old, type: type)
    }

    private func uploadImage(imageData: Data, expense: Expense) async throws -> String {
        guard let expenseId = expense.id else { return "" }
        return try await storageManager.uploadAttachment(for: .expense, id: expenseId, attachmentData: imageData) ?? ""
    }

    private func hasExpenseChanged(_ expense: Expense, oldExpense: Expense) -> Bool {
        return oldExpense.name != expense.name || oldExpense.amount != expense.amount ||
        oldExpense.date.dateValue() != expense.date.dateValue() ||
        oldExpense.updatedAt?.dateValue() != expense.updatedAt?.dateValue() ||
        oldExpense.paidBy != expense.paidBy || oldExpense.updatedBy != expense.updatedBy ||
        oldExpense.note != expense.note || oldExpense.imageUrl != expense.imageUrl ||
        oldExpense.splitTo != expense.splitTo || oldExpense.splitType != expense.splitType ||
        oldExpense.splitData != expense.splitData || oldExpense.isActive != expense.isActive
    }

    public func updateExpense(group: Groups, expense: Expense, oldExpense: Expense, type: ActivityType) async throws -> Expense {
        try await store.updateExpense(groupId: group.id ?? "", expense: expense)
        try await addActivityLogForExpense(group: group, expense: expense, oldExpense: oldExpense, type: type)
        return expense
    }

    private func addActivityLogForExpense(group: Groups, expense: Expense, oldExpense: Expense, type: ActivityType) async throws {
        guard let user = preference.user, type != .none else { return }

        let involvedUserIds = getInvolvedUserIds(oldExpense: oldExpense, expense: expense, user: user)
        let context = ActivityLogContext(group: group, expense: expense, type: type, currentUser: user)
        try await addActivityLogsInParallel(for: involvedUserIds, context: context)
    }

    private func getInvolvedUserIds(oldExpense: Expense, expense: Expense, user: AppUser) -> Set<String> {
        var memberIds = Set<String>()
        memberIds.formUnion(oldExpense.splitTo)
        memberIds.formUnion(oldExpense.paidBy.keys)
        memberIds.formUnion(expense.splitTo)
        memberIds.formUnion(expense.paidBy.keys)
        memberIds.insert(user.id)
        memberIds.insert(expense.addedBy)
        if let updatedBy = expense.updatedBy {
            memberIds.insert(updatedBy)
        }
        return memberIds
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
                           expenseName: expense.name, amount: amount, amountCurrency: expense.currencyCode)
    }

    private func addActivityLog(context: ActivityLogContext) async -> Error? {
        if let activity = createActivityLogForExpense(context: context), let memberId = context.memberId {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                LogD("ExpenseRepository: \(#function) Activity log added successfully for \(memberId).")
            } catch {
                LogE("ExpenseRepository: \(#function) Failed to add activity log for \(memberId): \(error).")
                return error
            }
        }
        return nil
    }

    public func fetchExpensesBy(groupId: String, limit: Int = 10,
                                lastDocument: DocumentSnapshot? = nil) async throws -> (expenses: [Expense],
                                                                                        lastDocument: DocumentSnapshot?) {
        return try await store.fetchExpensesBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchExpenses(groupId: String, startDate: Date?, endDate: Date) async throws -> [Expense] {
        try await store.fetchExpenses(groupId: groupId, startDate: startDate, endDate: endDate)
    }

    public func fetchExpenseBy(groupId: String, expenseId: String) async throws -> Expense {
        return try await store.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
    }

    public func fetchExpensesOfAllGroups(userId: String, activeGroupIds: [String], limit: Int = 10,
                                         lastDocument: DocumentSnapshot? = nil) async throws -> (expenses: [Expense],
                                                                                                 lastDocument: DocumentSnapshot?) {
        return try await store.fetchExpensesOfAllGroups(userId: userId, activeGroupIds: activeGroupIds,
                                                        limit: limit, lastDocument: lastDocument)
    }
}
