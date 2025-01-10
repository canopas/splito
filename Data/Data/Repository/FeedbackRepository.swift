//
//  FeedbackRepository.swift
//  Data
//
//  Created by Nirali Sonani on 02/01/25.
//

import Foundation
import UIKit

public class FeedbackRepository: ObservableObject {

    @Inject private var store: FeedbackStore
    @Inject private var storageManager: StorageManager

    public func addFeedback(feedback: Feedback) async throws {
        try await store.addFeedback(feedback: feedback)
    }

    public func uploadAttachment(attachmentId: String, attachmentData: Data,
                                 attachmentType: StorageManager.AttachmentType) async throws -> String? {
        return try await storageManager.uploadAttachment(for: .feedback, id: attachmentId,
                                                         attachmentData: attachmentData, attachmentType: attachmentType)
    }

    public func deleteAttachment(attachmentUrl: String) async throws {
        try await storageManager.deleteAttachment(attachmentUrl: attachmentUrl)
    }
}
