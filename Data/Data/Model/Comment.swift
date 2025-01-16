//
//  Comment.swift
//  Data
//
//  Created by Amisha Italiya on 10/01/25.
//

import FirebaseFirestore

public struct Comment: Codable, Hashable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var parentId: String
    public var comment: String
    public var commentedBy: String
    public var likedBy: [String]
    public var commentedAt: Timestamp

    public init(parentId: String, comment: String, commentedBy: String,
                likedBy: [String] = [], commentedAt: Timestamp = Timestamp()) {
        self.parentId = parentId
        self.comment = comment
        self.commentedBy = commentedBy
        self.likedBy = likedBy
        self.commentedAt = commentedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case comment = "comment"
        case commentedBy = "commented_by"
        case likedBy = "liked_by"
        case commentedAt = "commented_at"
    }
}
