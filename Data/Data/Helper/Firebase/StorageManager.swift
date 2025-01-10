//
//  StorageManager.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import FirebaseStorage

public class StorageManager: ObservableObject {

    public enum ImageStoreType {
        case user
        case group
        case expense
        case payment
        case feedback

        var pathName: String {
            switch self {
            case .user:
                "user_images"
            case .group:
                "group_images"
            case .expense:
                "expense_images"
            case .payment:
                "payment_images"
            case .feedback:
                "feedback_attachments"
            }
        }
    }

    public enum AttachmentType {
        case image
        case video

        var contentType: String {
            switch self {
            case .image:
                return "image/jpg"
            case .video:
                return "video/mp4"
            }
        }
    }

    private let storage = Storage.storage()

    public func uploadAttachment(for storeType: ImageStoreType, id: String, attachmentData: Data, attachmentType: AttachmentType = .image) async throws -> String? {
        let storageRef = storage.reference(withPath: "/\(storeType.pathName)/\(id)")

        let metadata = StorageMetadata()
        metadata.contentType = attachmentType.contentType

        do {
            // Upload the attachment data asynchronously
            _ = try await storageRef.putDataAsync(attachmentData, metadata: metadata)

            // Retrieve the download URL asynchronously
            let attachmentUrl = try await storageRef.downloadURL().absoluteString
            LogD("StorageManager: \(#function) Attachment successfully uploaded to Firebase.")
            return attachmentUrl
        } catch {
            LogE("StorageManager: \(#function) Failed to upload attachment: \(error).")
            throw error
        }
    }

    public func updateImage(for type: ImageStoreType, id: String, url: String, imageData: Data) async throws -> String? {
        try await deleteAttachment(attachmentUrl: url)

        // Upload the new image asynchronously
        return try await uploadAttachment(for: type, id: id, attachmentData: imageData)
    }

    public func deleteAttachment(attachmentUrl: String) async throws {
        do {
            let storageRef = storage.reference(forURL: attachmentUrl)
            try await storageRef.delete()
            LogD("StorageManager: \(#function) Image deleted successfully.")
        } catch {
            LogE("StorageManager: \(#function) Failed to delete image: \(error).")
            throw error
        }
    }
}

extension UIImage {
    func aspectFittedToHeight(_ newHeight: CGFloat) -> UIImage {
        let scale = newHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
