//
//  GroupStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import FirebaseFirestore

class GroupStore: ObservableObject {

    private static let COLLECTION_NAME: String = "groups"

    @Inject private var database: Firestore
    @Inject private var preference: SplitoPreference

    private var groupReference: CollectionReference {
        database.collection(GroupStore.COLLECTION_NAME)
    }

    func getNewGroupDocument() async throws -> DocumentReference {
        return groupReference.document()
    }

    func createGroup(document: DocumentReference, group: Groups) async throws {
        try document.setData(from: group)
    }

    func addMemberToGroup(groupId: String, memberId: String) async throws {
        // Wrap the updateData in a Task for async handling
        try await groupReference.document(groupId).updateData([
            "updated_at": Timestamp(),
            "updated_by": memberId,
            "members": FieldValue.arrayUnion([memberId])
        ])
    }

    func updateGroup(group: Groups) async throws {
        if let groupId = group.id {
            try groupReference.document(groupId).setData(from: group, merge: false)
        } else {
            LogE("GroupStore: \(#function) Group not found.")
            throw ServiceError.dataNotFound
        }
    }

    func streamLatestGroupBy(id: String) -> AsyncStream<Groups?> {
        AsyncStream { continuation in
            let listener = groupReference.document(id).addSnapshotListener { snapshot, error in
                if let error {
                    LogE("GroupStore: \(#function) Error fetching document: \(error).")
                    continuation.finish()
                    return
                }

                guard let snapshot else {
                    LogE("GroupStore: \(#function) Snapshot is nil for requested Group.")
                    continuation.yield(nil)
                    return
                }

                do {
                    let group = try snapshot.data(as: Groups.self)
                    continuation.yield(group)
                } catch {
                    LogE("GroupStore: \(#function) Error decoding Group data: \(error).")
                    continuation.finish()
                }
            }

            // Clean up: Remove listener when the stream is cancelled
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func fetchGroupsBy(userId: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> (data: [Groups], lastDocument: DocumentSnapshot?) {
        var query = groupReference
            .whereField("is_active", isEqualTo: true)
            .whereField("members", arrayContains: userId)
            .order(by: "updated_at", descending: true)
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        return try await query.getDocuments(as: Groups.self)
    }

    func fetchGroupBy(id: String) async throws -> Groups? {
        return try await groupReference.document(id).getDocument(as: Groups.self, source: .server)
    }
}
