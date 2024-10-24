//
//  ActivityLogsFunctions.swift
//  Splito
//
//  Created by Nirali Sonani on 15/10/24.
//

import Data
import FirebaseFirestore

func createActivityLogForExpense(context: ActivityLogContext) -> ActivityLog? {
    guard let groupId = context.group?.id, let expense = context.expense, let expenseId = expense.id, let currentUser = context.currentUser, let memberId = context.memberId else { return nil }

    let amount = expense.getCalculatedSplitAmountOf(member: memberId)
    let actionUserName = (memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial

    return ActivityLog(
        type: context.type,
        groupId: groupId,
        activityId: expenseId,
        groupName: context.group?.name ?? "",
        actionUserName: actionUserName,
        recordedOn: Timestamp(date: Date()),
        expenseName: context.expense?.name,
        amount: amount
    )
}

func createActivityLogForTransaction(context: ActivityLogContext) -> ActivityLog? {
    guard let groupId = context.group?.id, let transaction = context.transaction, let transactionId = transaction.id, let currentUser = context.currentUser else { return nil }

    let actionUserName = (context.memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial
    let amount: Double = (context.memberId == transaction.payerId) ? transaction.amount : (context.memberId == transaction.receiverId) ? -transaction.amount : 0

    return ActivityLog(
        type: context.type,
        groupId: groupId,
        activityId: transactionId,
        groupName: context.group?.name ?? "",
        actionUserName: actionUserName,
        recordedOn: Timestamp(date: Date()),
        payerName: context.payerName,
        receiverName: context.receiverName,
        amount: amount
    )
}

func createActivityLogForGroup(context: ActivityLogContext) -> ActivityLog? {
    guard let groupId = context.group?.id, let memberId = context.memberId, let currentUser = context.currentUser else { return nil }

    let actionUserName = (memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial

    return ActivityLog(
        type: context.type,
        groupId: groupId,
        activityId: groupId,
        groupName: context.group?.name ?? "",
        actionUserName: actionUserName,
        recordedOn: Timestamp(date: Date()),
        previousGroupName: context.previousGroupName,
        removedMemberName: context.removedMemberName
    )
}

struct ActivityLogContext {
    var group: Groups?
    var expense: Expense?
    var transaction: Transactions?
    let type: ActivityType
    var memberId: String?
    var currentUser: AppUser?
    var payerName: String?
    var receiverName: String?
    var previousGroupName: String?
    var removedMemberName: String?
}
