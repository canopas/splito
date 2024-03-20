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
    public var createdBy: String
    public var members: [Member]
    public var imageUrl: String?
    public var createdAt: Timestamp

    public init(name: String, createdBy: String, members: [Member], imageUrl: String? = nil, createdAt: Timestamp) {
        self.name = name
        self.createdBy = createdBy
        self.members = members
        self.imageUrl = imageUrl
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case members
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}
