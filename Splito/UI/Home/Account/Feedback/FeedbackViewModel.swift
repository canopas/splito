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
    private let TITLE_CHARACTER_MIN_LIMIT = 3
    private let VIDEO_SIZE_LIMIT_IN_BYTES = 5000000 // 5 MB
    private let IMAGE_SIZE_LIMIT_IN_BYTES = 3000000 // 3 MB

    @Inject private var preference: SplitoPreference
    @Inject private var feedbackRepository: FeedbackRepository

    @Published var description: String = ""
    @Published private var uploadedAttachmentIDs: Set<String> = Set<String>()

    @Published var failedAttachments: [Attachment] = []
    @Published var attachmentsUrls: [(id: String, url: String)] = []
    @Published var selectedAttachments: [Attachment] = []
    @Published var uploadingAttachments: [Attachment] = []

    @Published var showMediaPicker: Bool = false
    @Published var showMediaPickerOption: Bool = false
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var isValidTitle: Bool = false
    @Published private(set) var shouldShowValidationMessage: Bool = false

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

// MARK: - Action Items
extension FeedbackViewModel {
    func onSubmitBtnTap() {
        guard let userId = preference.user?.id, isValidTitle else {
            shouldShowValidationMessage = !isValidTitle
            return
        }

        let feedback = Feedback(title: title, description: description, userId: userId,
                                attachmentUrls: attachmentsUrls.map { $0.url }, appVersion: DeviceInfo.appVersionName,
                                deviceName: UIDevice.current.name, deviceOsVersion: UIDevice.current.systemVersion)
        submitFeedback(feedback: feedback)
    }

    private func submitFeedback(feedback: Feedback) {
        Task { [weak self] in
            do {
                self?.showLoader = true
                try await self?.feedbackRepository.addFeedback(feedback: feedback)
                self?.showLoader = false
                self?.showAlert = true
                self?.alert = .init(message: "Thanks! your feedback has been recorded.",
                                    positiveBtnTitle: "Ok",
                                    positiveBtnAction: { [weak self] in self?.router.pop() })
                LogD("FeedbackViewModel: \(#function) Feedback submitted successfully.")
            } catch {
                self?.showLoader = false
                self?.handleError()
                LogE("FeedbackViewModel: \(#function) Failed to submit feedback: \(error).")
            }
        }
    }

    func onMediaPickerSheetDismiss(attachments: [Attachment]) {
        for attachment in attachments {
            selectedAttachments.append(attachment)
            upload(attachment: attachment)
        }
    }

    func handleAttachmentTap() {
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
        upload(attachment: selectedAttachments[index])
        uploadedAttachmentIDs.insert(attachment.id)
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .gallery:
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

    private func upload(attachment: Attachment) {
        if uploadedAttachmentIDs.contains(attachment.id) { return }

        if let imageData = attachment.image?.jpegRepresentationData {
            validateAndUploadAttachment(data: imageData, attachment: attachment, maxSize: IMAGE_SIZE_LIMIT_IN_BYTES, type: .image)
        } else if let videoData = attachment.videoData {
            validateAndUploadAttachment(data: videoData, attachment: attachment, maxSize: VIDEO_SIZE_LIMIT_IN_BYTES, type: .video)
        }
    }

    private func validateAndUploadAttachment(data: Data, attachment: Attachment, maxSize: Int, type: StorageManager.AttachmentType) {
        if data.count <= maxSize {
            uploadAttachment(data: data, attachment: attachment, type: type)
        } else {
            selectedAttachments.removeAll { $0.id == attachment.id }
            let message = type == .image ? "The image size exceeds the maximum allowed limit. Please select a smaller image."
            : "The video size exceeds the maximum allowed limit. Please select a smaller video."
            handleError(message: message)
        }
    }

    private func uploadAttachment(data: Data, attachment: Attachment, type: StorageManager.AttachmentType) {
        uploadingAttachments.append(attachment)

        Task { [weak self] in
            do {
                let attachmentId = attachment.id
                let attachmentUrl = try await self?.feedbackRepository.uploadAttachment(attachmentId: attachmentId,
                                                                                        attachmentData: data, attachmentType: type)
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
    }

    // MARK: - Error Handling
    func handleError(message: String? = nil) {
        if let message {
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: message))
        } else {
            showToastForError()
        }
    }
}

extension FeedbackViewModel {
    enum FocusedField {
        case title, description
    }
}
