//
//  Expense.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public struct Expense: Codable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    let name: String
    let amount: Double
    let date: Timestamp
    let paidBy: String
    let splitTo: [String] // Reference to user ids involved in the split
    let groupId: String
    let splitType: SplitType

    public init(name: String, amount: Double, date: Timestamp, paidBy: String,
                splitTo: [String], groupId: String, splitType: SplitType = .equally) {
        self.name = name
        self.amount = amount
        self.date = date
        self.paidBy = paidBy
        self.splitTo = splitTo
        self.groupId = groupId
        self.splitType = splitType
    }

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case date
        case paidBy = "paid_by"
        case splitTo = "split_to"
        case groupId = "group_id"
        case splitType = "split_type"
    }
}

public enum SplitType: String, Codable {
    case equally
}
