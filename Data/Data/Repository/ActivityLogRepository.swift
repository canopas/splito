//
//  ActivityLogRepository.swift
//  Data
//
//  Created by Amisha Italiya on 14/10/24.
//

import FirebaseFirestore

public class ActivityLogRepository: ObservableObject {

    @Inject private var store: ActivityLogStore

    public func streamLatestActivityLogs(userId: String) -> AsyncStream<[ActivityLog]?> {
        store.streamLatestActivityLogs(userId: userId)
    }

    public func addActivityLog(userId: String, activity: ActivityLog) async throws {
        return try await store.addActivityLog(for: userId, activity: activity)
    }

    public func fetchActivitiesBy(userId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (data: [ActivityLog], lastDocument: DocumentSnapshot?) {
        return try await store.fetchActivitiesBy(userId: userId, limit: limit, lastDocument: lastDocument)
    }
}

struct ActivityLogContext {
    var group: Groups?
    var expense: Expense?
    var transaction: Transactions?
    let type: ActivityType
    var memberId: String?
    var currentUser: AppUser?
    var payerName: String?
    var receiverName: String?
    var paymentReason: String?
    var previousGroupName: String?
    var removedMemberName: String?
}
