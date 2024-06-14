//
//  Transaction.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import FirebaseFirestore

public struct Transactions: Codable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var payerId: String
    public var receiverId: String
    public let groupId: String
    public var amount: Double
    public var date: Timestamp

    public init(payerId: String, receiverId: String, groupId: String, amount: Double, date: Timestamp) {
        self.payerId = payerId
        self.receiverId = receiverId
        self.groupId = groupId
        self.amount = amount
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case payerId = "payer_id"
        case receiverId = "receiver_id"
        case groupId = "group_id"
        case amount
        case date
    }
}
