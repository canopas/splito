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
    public var note: String?
    public var imageUrl: String?
    public var amount: Double
    public var date: Timestamp
    public var updatedAt: Timestamp
    public var isActive: Bool

    public init(payerId: String, receiverId: String, addedBy: String, updatedBy: String, note: String? = nil,
                imageUrl: String? = nil, amount: Double, date: Timestamp, updatedAt: Timestamp = Timestamp(), isActive: Bool = true) {
        self.payerId = payerId
        self.receiverId = receiverId
        self.addedBy = addedBy
        self.updatedBy = updatedBy
        self.note = note
        self.imageUrl = imageUrl
        self.amount = amount
        self.date = date
        self.updatedAt = updatedAt
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case payerId = "payer_id"
        case receiverId = "receiver_id"
        case addedBy = "added_by"
        case updatedBy = "updated_by"
        case note = "note"
        case imageUrl = "image_url"
        case amount
        case date
        case updatedAt = "updated_at"
        case isActive = "is_active"
    }
}
