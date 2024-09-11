//
//  GroupStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestore

class GroupStore: ObservableObject {

    private static let COLLECTION_NAME: String = "groups"

    @Inject private var database: Firestore
    @Inject private var preference: SplitoPreference

    private var groupsCollection: CollectionReference {
        database.collection(GroupStore.COLLECTION_NAME)
    }

    func createGroup(group: Groups) async throws -> String {
        let documentRef = try groupsCollection.addDocument(from: group)
        return documentRef.documentID
    }

    func addMemberToGroup(groupId: String, memberId: String) async throws {
        // Wrap the updateData in a Task for async handling
        try await groupsCollection.document(groupId).updateData([
            "members": FieldValue.arrayUnion([memberId])
        ])
    }

    func updateGroup(group: Groups) async throws {
        if let groupId = group.id {
            try groupsCollection.document(groupId).setData(from: group, merge: false)
        } else {
            LogE("GroupStore :: \(#function) Group not found.")
            throw ServiceError.dataNotFound
        }
    }

    func fetchGroupsBy(userId: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> (data: [Groups], lastDocument: DocumentSnapshot?) {
        var query = groupsCollection
            .whereField("is_active", isEqualTo: true)
            .whereField("members", arrayContains: userId)
            .order(by: "created_at", descending: true)
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        return try await query.getDocuments(as: Groups.self)
    }

    func fetchGroupBy(id: String) async throws -> Groups? {
        try await groupsCollection.document(id).getDocument(as: Groups.self, source: .server)
    }
}
