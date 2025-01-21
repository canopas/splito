//
//  CommentRepository.swift
//  Data
//
//  Created by Amisha Italiya on 10/01/25.
//

import FirebaseFirestore

public class CommentRepository {

    @Inject private var store: CommentStore
    @Inject private var preference: SplitoPreference
    @Inject private var activityLogRepository: ActivityLogRepository

    public func addComment(group: Groups, expense: Expense? = nil, transaction: Transactions? = nil,
                           comment: Comment, existingCommenterIds: [String]) async throws -> Comment? {
        guard let groupId = group.id else { return nil }

        let addedComment = try await store.addComment(groupId: groupId,
                                                      parentId: expense != nil ? expense?.id ?? "" : transaction?.id ?? "",
                                                      comment: comment, isForExpenseComment: expense != nil)

        try await addActivityLogsInParallel(group: group, expense: expense,
                                            transaction: transaction, comment: comment.comment,
                                            existingCommenterIds: existingCommenterIds)
        return addedComment
    }

    /// Add activity logs for all involved users asynchronously and in parallel
    private func addActivityLogsInParallel(group: Groups, expense: Expense? = nil, transaction: Transactions? = nil,
                                           comment: String, existingCommenterIds: [String]) async throws {
        guard let user = preference.user else { return }

        var errors: [Error] = []
        let involvedUserIds = getInvolvedUserIds(expense: expense, transaction: transaction,
                                                 user: user, existingCommenterIds: existingCommenterIds)

        await withTaskGroup(of: Error?.self) { taskGroup in
            _ = involvedUserIds.compactMap { memberId in
                taskGroup.addTask { [weak self] in
                    guard let self else { return nil }
                    let context = createActivityLogContext(expense: expense, transaction: transaction, group: group,
                                                           comment: comment, memberId: memberId)
                    return await self.addActivityLog(context: context)
                }
            }

            for await error in taskGroup {
                if let error {
                    errors.append(error)
                }
            }
        }

        if let error = errors.first {
            throw error
        }
    }

    /// Retrieves the user IDs involved in an expense or transaction to add log for comment
    private func getInvolvedUserIds(expense: Expense? = nil, transaction: Transactions? = nil,
                                    user: AppUser, existingCommenterIds: [String]) -> Set<String> {
        var memberIds = Set<String>()
        memberIds.insert(user.id)  // Include comment author id
        memberIds.formUnion(existingCommenterIds)  // Include all existing commenter ids

        if let expense {
            memberIds.formUnion(expense.participants ?? [])
            memberIds.insert(expense.addedBy)
            memberIds.insert(expense.updatedBy ?? "")
        } else if let transaction {
            memberIds.insert(transaction.payerId)
            memberIds.insert(transaction.receiverId)
            memberIds.insert(transaction.addedBy)
            memberIds.insert(transaction.updatedBy ?? "")
        }
        return memberIds
    }

    /// Create ActivityLogContext for expense or transaction
    private func createActivityLogContext(expense: Expense? = nil, transaction: Transactions? = nil,
                                          group: Groups, comment: String, memberId: String) -> ActivityLogContext? {
        guard let user = preference.user else { return nil }
        var context: ActivityLogContext?

        if let expense {
            context = ActivityLogContext(group: group, expense: expense, comment: comment,
                                         type: .expenseCommentAdded, memberId: memberId, currentUser: user)
        } else if let transaction {
            context = ActivityLogContext(group: group, transaction: transaction, comment: comment,
                                         type: .transactionCommentAdded, memberId: memberId,
                                         currentUser: user, paymentReason: transaction.reason)
        }

        return context
    }

    /// Add activity log for comment
    private func addActivityLog(context: ActivityLogContext?) async -> Error? {
        if let context, let activity = createActivityLogForComment(context: context),
           let memberId = context.memberId {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                LogD("CommentRepository: \(#function) Activity log added successfully for \(memberId).")
            } catch {
                LogE("CommentRepository: \(#function) Failed to add activity log for \(memberId): \(error).")
                return error
            }
        }
        return nil
    }

    /// Create activity log for expense or transaction comment
    private func createActivityLogForComment(context: ActivityLogContext) -> ActivityLog? {
        guard let group = context.group, let groupId = group.id, let currentUser = context.currentUser,
              let memberId = context.memberId else { return nil }
        let actionUserName = (memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial

        if let expense = context.expense, let expenseId = expense.id {
            let amount = expense.getCalculatedSplitAmountOf(member: memberId)
            return ActivityLog(type: context.type, groupId: groupId, activityId: expenseId, groupName: group.name,
                               actionUserName: actionUserName, recordedOn: Timestamp(date: Date()),
                               expenseName: expense.name, comment: context.comment, amount: amount)

        } else if let transaction = context.transaction, let transactionId = transaction.id {
            let amount = (memberId == transaction.payerId) ? transaction.amount : (memberId == transaction.receiverId) ? -transaction.amount : 0
            return ActivityLog(type: context.type, groupId: groupId, activityId: transactionId,
                               groupName: context.group?.name ?? "", actionUserName: actionUserName,
                               recordedOn: Timestamp(date: Date()), comment: context.comment, payerName: context.payerName,
                               receiverName: context.receiverName, paymentReason: context.paymentReason, amount: amount)
        }
        return nil
    }

    public func fetchCommentsBy(groupId: String, parentId: String, limit: Int = 10,
                                lastDocument: DocumentSnapshot? = nil,
                                isForExpenseComment: Bool = true) async throws -> (data: [Comment],
                                                                                   lastDocument: DocumentSnapshot?) {
        return try await store.fetchCommentsBy(groupId: groupId, parentId: parentId, limit: limit,
                                               lastDocument: lastDocument, isForExpenseComment: isForExpenseComment)
    }
}
