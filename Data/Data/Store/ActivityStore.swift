//
//  ActivityStore.swift
//  Data
//
//  Created by Nirali Sonani on 14/10/24.
//

import FirebaseFirestore

class ActivityStore: ObservableObject {

    private let COLLECTION_NAME: String = "users"
    private let SUB_COLLECTION_NAME: String = "activity"

    @Inject private var database: Firestore

    private func activityReference(userId: String) -> CollectionReference {
        database
            .collection(COLLECTION_NAME)
            .document(userId)
            .collection(SUB_COLLECTION_NAME)
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

        return try await query.getDocuments(as: ActivityLog.self)
    }

    func deleteAllLogs(for userId: String) async throws {
        let batchSize = 15
        var lastDocument: DocumentSnapshot?

        repeat {
            // Fetch a batch of activities
            let (activities, lastDoc) = try await fetchActivitiesBy(userId: userId, limit: batchSize, lastDocument: lastDocument)
            lastDocument = lastDoc

            guard !activities.isEmpty else { break }

            // Create a new batch
            let batch = database.batch()

            // Add delete operations to the batch
            for activity in activities {
                let documentRef = activityReference(userId: userId).document(activity.id!)
                batch.deleteDocument(documentRef)
            }

            // Commit the batch
            try await batch.commit()

        } while lastDocument != nil
    }
}
