//
//  ActivityLogsFunctions.swift
//  Splito
//
//  Created by Nirali Sonani on 15/10/24.
//

import Data
import FirebaseFirestore
import BaseStyle

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
