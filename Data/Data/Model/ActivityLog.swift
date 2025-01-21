//
//  ActivityLog.swift
//  Data
//
//  Created by Amisha Italiya on 14/10/24.
//

import FirebaseFirestore

public struct ActivityLog: Codable, Identifiable, Hashable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    /// The type of activity (e.g., group created, expense updated)
    public let type: ActivityType
    public let groupId: String

    /// The id of the activity (e.g., expense or transaction)
    public let activityId: String
    public let groupName: String

    /// The name of the user who performed the action
    public let actionUserName: String
    public let recordedOn: Timestamp
    public let previousGroupName: String?
    public let removedMemberName: String?
    public let expenseName: String?
    public let comment: String?
    public let payerName: String?
    public let receiverName: String?
    public let paymentReason: String?
    public let amount: Double?
    public var amountCurrency: String? = Currency.defaultCurrency.code

    public init(type: ActivityType, groupId: String, activityId: String, groupName: String, actionUserName: String,
                recordedOn: Timestamp, previousGroupName: String? = nil, removedMemberName: String? = nil,
                expenseName: String? = nil, comment: String? = nil, payerName: String? = nil,
                receiverName: String? = nil, paymentReason: String? = nil, amount: Double? = nil,
                amountCurrency: String? = nil) {
        self.type = type
        self.groupId = groupId
        self.activityId = activityId
        self.groupName = groupName
        self.actionUserName = actionUserName
        self.recordedOn = recordedOn
        self.previousGroupName = previousGroupName
        self.removedMemberName = removedMemberName
        self.expenseName = expenseName
        self.comment = comment
        self.payerName = payerName
        self.receiverName = receiverName
        self.paymentReason = paymentReason
        self.amount = amount
        self.amountCurrency = amountCurrency
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case groupId = "group_id"
        case activityId = "activity_id"
        case groupName = "group_name"
        case actionUserName = "action_user_name"
        case recordedOn = "recorded_on"
        case previousGroupName = "previous_group_name"
        case removedMemberName = "removed_member_name"
        case expenseName = "expense_name"
        case comment
        case payerName = "payer_name"
        case receiverName = "receiver_name"
        case paymentReason = "payment_reason"
        case amount
        case amountCurrency = "amount_currency"
    }
}

public enum ActivityType: String, Codable {
    case none
    case groupCreated = "group_created"
    case groupUpdated = "group_updated"
    case groupDeleted = "group_deleted"
    case groupRestored = "group_restored"
    case groupNameUpdated = "group_name_updated"
    case groupImageUpdated = "group_image_updated"
    case groupMemberLeft = "group_member_left"
    case groupMemberRemoved = "group_member_removed"
    case expenseAdded = "expense_added"
    case expenseUpdated = "expense_updated"
    case expenseDeleted = "expense_deleted"
    case expenseRestored = "expense_restored"
    case expenseCommentAdded = "expense_comment_added"
    case transactionAdded = "transaction_added"
    case transactionUpdated = "transaction_updated"
    case transactionDeleted = "transaction_deleted"
    case transactionRestored = "transaction_restored"
    case transactionCommentAdded = "transaction_comment_added"
}
