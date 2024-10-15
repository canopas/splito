//
//  ActivityRepository.swift
//  Data
//
//  Created by Nirali Sonani on 14/10/24.
//

import FirebaseFirestore

public class ActivityRepository: ObservableObject {

    @Inject private var store: ActivityStore

    public func addActivityLog(userId: String, activity: ActivityLog) async throws {
        return try await store.addActivityLog(for: userId, activity: activity)
    }

    public func fetchActivitiesBy(userId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (data: [ActivityLog], lastDocument: DocumentSnapshot?) {
        return try await store.fetchActivitiesBy(userId: userId, limit: limit, lastDocument: lastDocument)
    }
}
