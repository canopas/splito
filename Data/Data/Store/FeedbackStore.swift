//
//  FeedbackStore.swift
//  Data
//
//  Created by Nirali Sonani on 02/01/25.
//

import FirebaseFirestore

class FeedbackStore: ObservableObject {

    private let COLLECTION_NAME: String = "feedbacks"

    @Inject private var database: Firestore

    private var feedbacksCollection: CollectionReference {
        database.collection(COLLECTION_NAME)
    }

    func addFeedback(feedback: Feedback) async throws {
        do {
            try database.collection(self.COLLECTION_NAME).addDocument(from: feedback)
        } catch {
            LogE("FeedbackStore: \(#function) Failed to add feedback: \(error).")
            throw error
        }
    }
}
