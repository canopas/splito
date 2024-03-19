//
//  Member.swift
//  Data
//
//  Created by Amisha Italiya on 13/03/24.
//

import FirebaseFirestore

public struct Member: Codable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var userId: String
    public var groupId: String
    public var totalBalance: Double?
    public var owesToOthers: Double?
    public var owedByOthers: Double?

    public init(userId: String, groupId: String, totalBalance: Double? = nil, owesToOthers: Double? = nil, owedByOthers: Double? = nil) {
        self.userId = userId
        self.groupId = groupId
        self.totalBalance = totalBalance
        self.owesToOthers = owesToOthers
        self.owedByOthers = owedByOthers
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case groupId = "group_id"
        case totalBalance = "total_balance"
        case owesToOthers = "owes_to_others"
        case owedByOthers = "owed_by_others"
    }
}
