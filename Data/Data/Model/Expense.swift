//
//  Expense.swift
//  Data
//
//  Created by Amisha Italiya on 20/03/24.
//

import FirebaseFirestore

public struct Expense: Codable, Hashable {

    public var id: String? // Automatically generated ID by Firestore

    public var name: String
    public var amount: Double
    public var date: Timestamp
    public var paidBy: [String: Double]
    public let addedBy: String
    public var splitTo: [String] // Reference to user ids involved in the split
    public var splitType: SplitType
    public var splitData: [String: Double]? // Use this to store percentage or share data

    public init(name: String, amount: Double, date: Timestamp, paidBy: [String: Double], addedBy: String,
                splitTo: [String], splitType: SplitType = .equally, splitData: [String: Double]? = [:]) {
        self.name = name
        self.amount = amount
        self.date = date
        self.paidBy = paidBy
        self.addedBy = addedBy
        self.splitTo = splitTo
        self.splitType = splitType
        self.splitData = splitData
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case amount
        case date
        case paidBy = "paid_by"
        case addedBy = "added_by"
        case splitTo = "split_to"
        case splitType = "split_type"
        case splitData = "split_data"
    }

    // Calculated properties for better UI representation
    public var formattedAmount: String {
        return amount.formattedCurrency
    }
}

public enum SplitType: String, Codable, CaseIterable {
    case equally
    case fixedAmount
    case percentage
    case shares
}
