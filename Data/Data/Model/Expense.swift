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
    let date: Date
    let paidBy: AppUser
    let splitTo: [String] // Reference to users involved in the split
    let splitType: SplitType

    public init(name: String, amount: Double, date: Date, paidBy: AppUser, splitTo: [String], splitType: SplitType) {
        self.name = name
        self.amount = amount
        self.date = date
        self.paidBy = paidBy
        self.splitTo = splitTo
        self.splitType = splitType
    }

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case date
        case paidBy = "paied_by"
        case splitTo = "split_to"
        case splitType = "split_type"
    }
}

public enum SplitType: String, Codable {
    case equally
}
