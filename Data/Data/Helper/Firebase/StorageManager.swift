//
//  StorageManager.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import Combine
import FirebaseStorage

public class StorageManager: ObservableObject {

    public enum ImageStoreType {
        case user
        case group

        var pathName: String {
            switch self {
            case .user:
                "user_images"
            case .group:
                "group_images"
            }
        }
    }

    private let storage = Storage.storage()

    public func uploadImage(for storeType: ImageStoreType, id: String, imageData: Data) async throws -> String? {
        let storageRef = storage.reference(withPath: "/\(storeType.pathName)/\(id)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg"

        do {
            // Upload the image data asynchronously
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

            // Retrieve the download URL asynchronously
            let imageUrl = try await storageRef.downloadURL().absoluteString
            LogD("StorageManager: Image successfully uploaded to Firebase!")
            return imageUrl
        } catch {
            LogE("StorageManager: \(#function) Failed: \(error.localizedDescription)")
            throw ServiceError.databaseError(error: error)
        }
    }

    public func updateImage(for type: ImageStoreType, id: String, url: String, imageData: Data) async throws -> String? {
        try await deleteImage(imageUrl: url)

        // Upload the new image asynchronously
        return try await uploadImage(for: type, id: id, imageData: imageData)
    }

    public func deleteImage(imageUrl: String) async throws {
        do {
            let storageRef = storage.reference(forURL: imageUrl)
            try await storageRef.delete()
        } catch {
            LogE("StorageManager: \(#function) Failed: \(error)")
            throw ServiceError.databaseError(error: error)
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
