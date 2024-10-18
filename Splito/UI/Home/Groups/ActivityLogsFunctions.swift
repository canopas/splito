//
//  ActivityLogsFunctions.swift
//  Splito
//
//  Created by Nirali Sonani on 15/10/24.
//

import Data
import FirebaseFirestore

func createActivityLogForExpense(expense: Expense, type: ActivityType, memberId: String, currentUser: AppUser, group: Groups?, amount: Double) -> ActivityLog? {
    guard let groupId = group?.id, let expenseId = expense.id else { return nil }

    let actionUserName = (memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial

    return ActivityLog(
        type: type,
        groupId: groupId,
        activityId: expenseId,
        groupName: group?.name ?? "",
        actionUserName: actionUserName,
        recordedOn: Timestamp(date: Date()),
        expenseName: expense.name,
        amount: amount
    )
}

func createActivityLogForTransaction(transaction: Transactions, type: ActivityType, actionUserName: String, payerName: String, receiverName: String, group: Groups?, amount: Double) -> ActivityLog? {
    guard let groupId = group?.id, let transactionId = transaction.id else { return nil }

    return ActivityLog(
        type: type,
        groupId: groupId,
        activityId: transactionId,
        groupName: group?.name ?? "",
        actionUserName: actionUserName,
        recordedOn: Timestamp(date: Date()),
        payerName: payerName,
        receiverName: receiverName,
        amount: amount
    )
 }

func createActivityLogForGroup(group: Groups?, type: ActivityType, memberId: String, actionUserName: String, previousGroupName: String? = nil, removedMemberName: String? = nil) -> ActivityLog? {
    guard let groupId = group?.id else { return nil }

    return ActivityLog(
        type: type,
        groupId: groupId,
        activityId: groupId,
        groupName: group?.name ?? "",
        actionUserName: actionUserName,
        recordedOn: Timestamp(date: Date()),
        previousGroupName: previousGroupName,
        removedMemberName: removedMemberName
    )
}
