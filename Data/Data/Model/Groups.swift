//
//  Groups.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import FirebaseFirestore

public struct Groups: Codable, Identifiable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var name: String
    public let createdBy: String
    public var imageUrl: String?
    public var members: [String]
    public var balance: [GroupMemberBalance]
    public let createdAt: Timestamp
    public var isDebtSimplified: Bool

    public init(name: String, createdBy: String, imageUrl: String? = nil, members: [String],
                balance: [GroupMemberBalance], createdAt: Timestamp, isDebtSimplified: Bool = true) {
        self.name = name
        self.createdBy = createdBy
        self.members = members
        self.balance = balance
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.isDebtSimplified = isDebtSimplified
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case members
        case balance
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case isDebtSimplified = "is_debt_simplified"
    }
}

public struct GroupMemberBalance: Codable, Hashable {
    public let id: String
    public var balance: Double

    public init(id: String, balance: Double) {
        self.id = id
        self.balance = balance
    }
}
