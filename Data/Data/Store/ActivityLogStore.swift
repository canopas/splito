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

    private var listener: ListenerRegistration?

    private func activityReference(userId: String) -> CollectionReference {
        database
            .collection(COLLECTION_NAME)
            .document(userId)
            .collection(SUB_COLLECTION_NAME)
    }

    deinit {
        listener?.remove()
    }

    func fetchLatestActivityLogs(userId: String, completion: @escaping ([ActivityLog]?) -> Void) {
        listener?.remove()
        listener = activityReference(userId: userId).addSnapshotListener { snapshot, error in
            if let error {
                LogE("ActivityLogStore: \(#function) Error fetching document: \(error).")
                completion(nil)
                return
            }

            guard let snapshot else {
                LogE("ActivityLogStore: \(#function) snapshot is nil for requested user.")
                completion(nil)
                return
            }

            let activityLogs: [ActivityLog] = snapshot.documents.compactMap { document in
                do {
                    return try document.data(as: ActivityLog.self)
                } catch {
                    LogE("ActivityLogStore: \(#function) Error decoding document data: \(error).")
                    return nil
                }
            }

            LogD("ActivityLogStore: \(#function) Latest activity logs fetched successfully.")
            completion(activityLogs)
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
