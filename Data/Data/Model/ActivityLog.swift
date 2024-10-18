//
//  ActivityLog.swift
//  Data
//
//  Created by Nirali Sonani on 14/10/24.
//

import FirebaseFirestore

public struct ActivityLog: Codable, Identifiable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public let type: ActivityType   // The type of activity (e.g., group added, expense updated)
    public let groupId: String
    public let activityId: String   // The ID of the activity (e.g., expense or transaction)
    public let groupName: String
    public let actionUserName: String   // The id of the user who performed the action
    public let recordedOn: Timestamp
    public let removedMemberName: String?
    public let expenseName: String?
    public let payerName: String?
    public let receiverName: String?
    public let amount: Double?

    public init(type: ActivityType, groupId: String, activityId: String, groupName: String, actionUserName: String, recordedOn: Timestamp, removedMemberName: String? = nil, expenseName: String? = nil, payerName: String? = nil, receiverName: String? = nil, amount: Double? = nil) {
        self.type = type
        self.groupId = groupId
        self.activityId = activityId
        self.groupName = groupName
        self.actionUserName = actionUserName
        self.recordedOn = recordedOn
        self.removedMemberName = removedMemberName
        self.expenseName = expenseName
        self.payerName = payerName
        self.receiverName = receiverName
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case groupId = "group_id"
        case activityId = "activity_id"
        case groupName = "group_name"
        case actionUserName = "action_user_name"
        case recordedOn = "recorded_on"
        case removedMemberName = "removed_member_name"
        case expenseName = "expense_name"
        case payerName = "payer_name"
        case receiverName = "receiver_name"
        case amount
    }
}

public enum ActivityType: String, Codable {
    case groupCreated = "group_created"
    case groupNameUpdated = "group_name_updated"
    case groupImageUpdated = "group_image_updated"
    case groupMemberRemoved = "group_member_removed"
    case groupMemberLeft = "group_member_left"
    case groupDeleted = "group_deleted"
    case expenseAdded = "expense_added"
    case expenseUpdated = "expense_updated"
    case expenseDeleted = "expense_deleted"
    case transactionAdded = "transaction_added"
    case transactionUpdated = "transaction_updated"
    case transactionDeleted = "transaction_deleted"
}
