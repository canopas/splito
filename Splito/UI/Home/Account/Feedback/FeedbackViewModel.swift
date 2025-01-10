//
//  FeedbackViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import SwiftUI
import Data
import BaseStyle

class FeedbackViewModel: BaseViewModel, ObservableObject {

    let MAX_ATTACHMENTS = 5
    private let TITLE_CHARACTER_MIN_LIMIT = 3
    private let VIDEO_SIZE_LIMIT_IN_BYTES = 5000000 // 5 MB
    private let IMAGE_SIZE_LIMIT_IN_BYTES = 3000000 // 3 MB

    @Inject private var preference: SplitoPreference
    @Inject private var feedbackRepository: FeedbackRepository

    @Published var failedAttachments: [Attachment] = []
    @Published var selectedAttachments: [Attachment] = []
    @Published var uploadingAttachments: [Attachment] = []
    @Published var attachmentsUrls: [(id: String, url: String)] = []
    @Published private var uploadedAttachmentIDs: Set<String> = Set<String>()

    @Published var showMediaPicker: Bool = false
    @Published var showMediaPickerOption: Bool = false
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var isValidTitle: Bool = false
    @Published private(set) var shouldShowValidationMessage: Bool = false

    @Published var description: String = ""

    @Published var title: String = "" {
        didSet {
            isValidTitle = title.count >= TITLE_CHARACTER_MIN_LIMIT
        }
    }

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }
}

// MARK: - User Actions
extension FeedbackViewModel {
    func onSubmitBtnTap() {
        guard let userId = preference.user?.id, isValidTitle else {
            shouldShowValidationMessage = !isValidTitle
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.showLoader = true
                let feedback = Feedback(
                    title: self.title, description: self.description, userId: userId,
                    attachmentUrls: self.attachmentsUrls.map { $0.url }, appVersion: DeviceInfo.appVersionName,
                    deviceName: DeviceInfo.deviceName, deviceOsVersion: DeviceInfo.deviceOsVersion
                )
                try await self.feedbackRepository.addFeedback(feedback: feedback)
                self.showLoader = false
                self.showAlert = true
                self.alert = .init(message: "Thanks! your feedback has been recorded.",
                                   positiveBtnTitle: "Ok",
                                   positiveBtnAction: { [weak self] in self?.router.pop() })
                LogD("FeedbackViewModel: \(#function) Feedback submitted successfully.")
            } catch {
                self.handleError()
                LogE("FeedbackViewModel: \(#function) Failed to submit feedback: \(error).")
            }
        }
    }

    func onMediaPickerSheetDismiss(attachments: [Attachment]) {
        for attachment in attachments {
            selectedAttachments.append(attachment)
            handleAttachmentUpload(attachment: attachment)
        }
    }

    func handleAddAttachmentTap() {
        if selectedAttachments.isEmpty {
            showMediaPicker = true
        } else {
            showMediaPickerOption = true
        }
    }

    func onRemoveAttachment(_ attachment: Attachment) {
        if let urlIndex = attachmentsUrls.firstIndex(where: { $0.id == attachment.id }) {
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.feedbackRepository.deleteAttachment(attachmentUrl: attachmentsUrls[urlIndex].url)
                    self.removeAttachmentFromArrays(attachmentId: attachment.id)
                    LogD("FeedbackViewModel: \(#function) Attachment deleted successfully.")
                } catch {
                    LogE("FeedbackViewModel: \(#function) Failed to delete attachment: \(error)")
                    self.handleError(message: "Failed to remove attachment.")
                }
            }
        }
    }

    func onRetryAttachment(_ attachment: Attachment) {
        guard let index = selectedAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }
        failedAttachments.removeAll { $0.id == attachment.id }
        handleAttachmentUpload(attachment: selectedAttachments[index])
        uploadedAttachmentIDs.insert(attachment.id)
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .gallery:
            if attachmentsUrls.count >= MAX_ATTACHMENTS {
                handleError(message: "Maximum \(MAX_ATTACHMENTS) attachments allowed.")
                return
            }
            showMediaPicker = true
        case .removeAll:
            removeAllAttachments()
        case .camera, .remove:
            break
        }
    }

    private func removeAllAttachments() {
        Task { [weak self] in
            guard let self else { return }
            for attachment in self.attachmentsUrls {
                do {
                    try await self.feedbackRepository.deleteAttachment(attachmentUrl: attachment.url)
                    self.removeAttachmentFromArrays(attachmentId: attachment.id, removeAllSelected: true)
                    LogD("FeedbackViewModel: \(#function) Attachment deleted successfully.")
                } catch {
                    LogE("FeedbackViewModel: \(#function) Failed to delete attachment: \(error)")
                    self.handleError(message: "Failed to remove attachment.")
                }
            }
        }
    }

    private func removeAttachmentFromArrays(attachmentId: String, removeAllSelected: Bool = false) {
        withAnimation { [weak self] in
            self?.attachmentsUrls.removeAll { $0.id == attachmentId }
            self?.selectedAttachments.removeAll { $0.id == attachmentId }
            self?.uploadingAttachments.removeAll { $0.id == attachmentId }

            if removeAllSelected {
                self?.failedAttachments.removeAll { $0.id == attachmentId }
                self?.uploadedAttachmentIDs.remove(attachmentId)
            }
        }
    }

    private func handleAttachmentUpload(attachment: Attachment) {
        if uploadedAttachmentIDs.contains(attachment.id) { return }

        if let imageData = attachment.image?.jpegRepresentationData {
            uploadAttachment(data: imageData, attachment: attachment, maxSize: IMAGE_SIZE_LIMIT_IN_BYTES, type: .image)
        } else if let videoData = attachment.videoData {
            uploadAttachment(data: videoData, attachment: attachment, maxSize: VIDEO_SIZE_LIMIT_IN_BYTES, type: .video)
        }
    }

    private func uploadAttachment(data: Data, attachment: Attachment, maxSize: Int, type: StorageManager.AttachmentType) {
        if data.count <= maxSize {
            uploadingAttachments.append(attachment)

            Task { [weak self] in
                do {
                    let attachmentId = attachment.id
                    let attachmentUrl = try await self?.feedbackRepository.uploadAttachment(attachmentId: attachmentId,
                                                                                            attachmentData: data,
                                                                                            attachmentType: type)
                    if let attachmentUrl {
                        self?.attachmentsUrls.append((id: attachmentId, url: attachmentUrl))
                        self?.uploadingAttachments.removeAll { $0.id == attachmentId }
                    }
                    LogD("FeedbackViewModel: \(#function) Attachment uploaded successfully.")
                } catch {
                    self?.failedAttachments.append(attachment)
                    self?.uploadingAttachments.removeAll { $0.id == attachment.id }
                    LogE("FeedbackViewModel: \(#function) Failed to upload attachment: \(error)")
                }
            }
        } else {
            selectedAttachments.removeAll { $0.id == attachment.id }
            let message = type == .image ? "The image size exceeds the maximum allowed limit. Please select a smaller image."
            : "The video size exceeds the maximum allowed limit. Please select a smaller video."
            handleError(message: message)
        }
    }

    // MARK: - Error Handling
    func handleError(message: String? = nil) {
        if let message {
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: message))
        } else {
            showLoader = false
            showToastForError()
        }
    }
}

extension FeedbackViewModel {
    enum FocusedField {
        case title, description
    }
}
