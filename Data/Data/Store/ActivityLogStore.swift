//
//  ActivityLogStore.swift
//  Data
//
//  Created by Amisha Italiya on 14/10/24.
//

import FirebaseFirestore

class ActivityLogStore: ObservableObject {

    private let COLLECTION_NAME: String = "users"
    private let SUB_COLLECTION_NAME: String = "activity"

    @Inject private var database: Firestore

    private func activityReference(userId: String) -> CollectionReference {
        database
            .collection(COLLECTION_NAME)
            .document(userId)
            .collection(SUB_COLLECTION_NAME)
    }

    func streamLatestActivityLogs(userId: String) -> AsyncStream<[ActivityLog]?> {
        AsyncStream { continuation in
            let query = activityReference(userId: userId)
                .order(by: "recorded_on", descending: true)
                .limit(to: 10)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    LogE("ActivityLogStore: \(#function) Error fetching document: \(error).")
                    continuation.finish()
                    return
                }

                guard let snapshot else {
                    LogE("ActivityLogStore: \(#function) snapshot is nil for requested user.")
                    continuation.finish()
                    return
                }

                do {
                    let activityLogs: [ActivityLog] = try snapshot.documents.compactMap { document in
                        try document.data(as: ActivityLog.self)
                    }
                    continuation.yield(activityLogs)
                    LogD("ActivityLogStore: \(#function) Latest activity logs fetched successfully.")
                } catch {
                    LogE("ActivityLogStore: \(#function) Error decoding document data: \(error).")
                    continuation.finish()
                }
            }

            // Clean up: Remove listener when the stream is cancelled
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func addActivityLog(for userId: String, activity: ActivityLog) async throws {
        let documentRef = activityReference(userId: userId).document()

        var newActivity = activity
        newActivity.id = documentRef.documentID

        try documentRef.setData(from: newActivity)
    }

    func fetchActivitiesBy(userId: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> (data: [ActivityLog], lastDocument: DocumentSnapshot?) {
        var query = activityReference(userId: userId)
            .order(by: "recorded_on", descending: true)
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        let snapshot = try await query.getDocuments(source: .server)
        let activityLogs = try snapshot.documents.compactMap { document in
            try document.data(as: ActivityLog.self)
        }

        return (activityLogs, snapshot.documents.last)
    }
}
