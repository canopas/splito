//
//  Activity.swift
//  Data
//
//  Created by Nirali Sonani on 14/10/24.
//

import FirebaseFirestore

public struct Activity: Codable, Identifiable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public let type: ActivityType   // The type of activity, e.g., group added, expense updated.
    public let groupId: String
    public let itemId: String   // The ID of the item (e.g., group, expense or transaction).
    public let groupName: String
    public let actionUserName: String   // The name of the user who performed the action.
    public let recordedOn: Timestamp
    public let groupImageUrl: String?
    public let expenseName: String?
    public let payerName: String?
    public let receiverName: String?
    public let amount: Double?

    public init(type: ActivityType, groupId: String, itemId: String, groupName: String, actionUserName: String, recordedOn: Timestamp, groupImageUrl: String? = nil, expenseName: String? = nil, payerName: String? = nil, receiverName: String? = nil, amount: Double? = nil) {
        self.type = type
        self.groupId = groupId
        self.itemId = itemId
        self.groupName = groupName
        self.actionUserName = actionUserName
        self.recordedOn = recordedOn
        self.groupImageUrl = groupImageUrl
        self.expenseName = expenseName
        self.payerName = payerName
        self.receiverName = receiverName
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case groupId = "group_id"
        case itemId = "item_id"
        case groupName = "group_name"
        case actionUserName = "action_user_name"
        case recordedOn = "recorded_on"
        case groupImageUrl = "group_image_url"
        case expenseName = "expense_name"
        case payerName = "payer_name"
        case receiverName = "receiver_name"
        case amount
    }
}

public enum ActivityType: String, Codable {
    case groupAdded = "group_added"
    case groupUpdated = "group_updated"
    case groupDeleted = "group_deleted"
    case expenseAdded = "expense_added"
    case expenseUpdated = "expense_updated"
    case expenseDeleted = "expense_deleted"
    case transactionAdded = "transaction_added"
    case transactionUpdated = "transaction_updated"
    case transactionDeleted = "transaction_deleted"
}
