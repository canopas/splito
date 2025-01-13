//
//  Transaction.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import FirebaseFirestore

public struct Transactions: Codable, Hashable, Identifiable {

    public var id: String? // Automatically generated ID by Firestore

    public var payerId: String
    public var receiverId: String
    public var date: Timestamp
    public let addedBy: String
    public var amount: Double
    public var currencyCode: String? = "INR"
    public var updatedBy: String?
    public var note: String?
    public var reason: String?
    public var imageUrl: String?
    public var updatedAt: Timestamp?
    public var isActive: Bool

    public init(payerId: String, receiverId: String, date: Timestamp, addedBy: String, amount: Double,
                currencyCode: String? = "INR", updatedBy: String? = nil, note: String? = nil, reason: String? = nil,
                imageUrl: String? = nil, updatedAt: Timestamp? = nil, isActive: Bool = true) {
        self.payerId = payerId
        self.receiverId = receiverId
        self.date = date
        self.addedBy = addedBy
        self.amount = amount
        self.currencyCode = currencyCode
        self.updatedBy = updatedBy
        self.note = note
        self.reason = reason
        self.imageUrl = imageUrl
        self.updatedAt = updatedAt
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case payerId = "payer_id"
        case receiverId = "receiver_id"
        case date
        case addedBy = "added_by"
        case amount
        case currencyCode = "currency_code"
        case updatedBy = "updated_by"
        case note
        case reason
        case imageUrl = "image_url"
        case updatedAt = "updated_at"
        case isActive = "is_active"
    }
}
