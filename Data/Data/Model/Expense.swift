//
//  Expense.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public struct Expense: Codable, Hashable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var name: String
    public var amount: Double
    public var date: Timestamp
    public var paidBy: String
    public let addedBy: String
    public var splitTo: [String] // Reference to user ids involved in the split
    public let groupId: String
    public var splitType: SplitType

    // Calculated properties for better UI representation
    public var formattedAmount: String {
        return amount.formattedCurrency
    }

    public init(name: String, amount: Double, date: Timestamp, paidBy: String, addedBy: String,
                splitTo: [String], groupId: String, splitType: SplitType = .equally) {
        self.name = name
        self.amount = amount
        self.date = date
        self.paidBy = paidBy
        self.addedBy = addedBy
        self.splitTo = splitTo
        self.groupId = groupId
        self.splitType = splitType
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case amount
        case date
        case paidBy = "paid_by"
        case addedBy = "added_by"
        case splitTo = "split_to"
        case groupId = "group_id"
        case splitType = "split_type"
    }
}

public enum SplitType: String, Codable {
    case equally = "equally"
    case percentage = "Percentage"
    case fixedAmount = "Fixed Amount"
}
