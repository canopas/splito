//
//  SharedCode.swift
//  Data
//
//  Created by Amisha Italiya on 12/03/24.
//

import FirebaseFirestore

public struct SharedCode: Codable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var code: String
    public var groupId: String
    public var expireDate: Timestamp

    public init(code: String, groupId: String, expireDate: Timestamp) {
        self.code = code
        self.groupId = groupId
        self.expireDate = expireDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case groupId = "group_id"
        case expireDate = "expire_date"
    }
}
