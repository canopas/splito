//
//  Transaction.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import FirebaseFirestore

public struct Transactions: Codable, Hashable, Identifiable {

    public var id: String? // Automatically generated ID by Firestore

    public let payerId: String
    public let receiverId: String
    public let addedBy: String
    public var updatedBy: String
    public var amount: Double
    public var date: Timestamp
    public var isActive: Bool

    public init(payerId: String, receiverId: String, addedBy: String, updatedBy: String, amount: Double, date: Timestamp, isActive: Bool = true) {
        self.payerId = payerId
        self.receiverId = receiverId
        self.addedBy = addedBy
        self.updatedBy = updatedBy
        self.amount = amount
        self.date = date
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case payerId = "payer_id"
        case receiverId = "receiver_id"
        case addedBy = "added_by"
        case updatedBy = "updated_by"
        case amount
        case date
        case isActive = "is_active"
    }
}
