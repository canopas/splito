//
//  StorageManager.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import Foundation
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

    public func uploadImage(for storeType: ImageStoreType, id: String, imageData: Data, completion: @escaping (String?) -> Void) {
        let storageRef = storage.reference(withPath: "/\(storeType.pathName)/\(id)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg"

        storageRef.putData(imageData, metadata: metadata) { _, error in
            if let error {
                LogE("StorageManager: Error while uploading file: \(error.localizedDescription)")
                completion(nil)
                return
            }

            storageRef.downloadURL { url, error in
                if let error {
                    LogE("StorageManager: Download url failed with error: \(error.localizedDescription)")
                    completion(nil) // Return nil for completion to indicate error
                } else if let imageUrl = url?.absoluteString {
                    LogD("StorageManager: Image successfully uploaded to Firebase!")
                    completion(imageUrl)
                }
            }
        }
    }

    public func updateImage(for type: ImageStoreType, id: String, url: String, imageData: Data, completion: @escaping (String?) -> Void) {
        deleteImage(imageUrl: url) { error in
            guard error == nil else { completion(nil) ; return }

            self.uploadImage(for: type, id: id, imageData: imageData, completion: completion)
        }
    }

    public func deleteImage(imageUrl: String, completion: @escaping (Error?) -> Void) {
        let storageRef = storage.reference(forURL: imageUrl)

        storageRef.delete { error in
            guard error == nil else {
                LogE("StorageManager: Error while deleting image: \(error as Any)")
                completion(error)
                return
            }
            completion(nil)
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
