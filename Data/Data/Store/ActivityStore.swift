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

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

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
            .limit(to: limit)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        return try await query.getDocuments(as: ActivityLog.self)
    }

    func listenToActivityLogs(for userId: String, completion: @escaping ([ActivityLog]?) -> Void) {
        listener?.remove() // Remove any previous listeners

        listener = activityReference(userId: userId).addSnapshotListener { snapshot, error in
            if let error {
                LogE("UserStore :: \(#function) Error fetching activities: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(nil)
                return
            }

            let activities = documents.compactMap { try? $0.data(as: ActivityLog.self) }
            completion(activities)
        }
    }
}
