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
                    print("StorageManager: Download url failed", error)
                    completion(nil) // Return nil for completion to indicate error
                } else if let imageUrl = url?.absoluteString {
                    print("StorageManager: Image successfully uploaded to Firebase!")
                    completion(imageUrl)
                }
            }
        }
    }

    public func deleteImage(imageUrl: String) {
        let storageRef = storage.reference(forURL: imageUrl)

        storageRef.delete { error in
            guard error != nil else {
                LogE("StorageManager: Error while deleting image: \(error as Any)")
                return
            }
        }
    }

    public func listAllFiles(storeType: ImageStoreType) {
        let storageRef = storage.reference().child(storeType.pathName)

        // List all items in the images folder
        storageRef.listAll { (result, error) in
            if let error {
                LogE("StorageManager: Error while listing all files: \(error)")
            }

            if let result {
                for item in result.items {
                    LogD("StorageManager: Item in images folder: \(item)")
                }
            }
        }
    }

    public func listItem(storeType: ImageStoreType) {
        let storageRef = storage.reference().child(storeType.pathName)

        // Create a completion handler - aka what the function should do after it listed all the items
        let _: (StorageListResult, Error?) -> Void = { (result, error) in
            if let error {
                LogE("StorageManager: error: \(error)")
            }

            let item = result.items
            LogD("StorageManager: item: \(item)")
        }

        // List the items
        storageRef.list(maxResults: 1) { result, error in
            if let error {
                LogE("StorageManager: error: \(error)")
            }

            let item = result?.items
            LogD("StorageManager: item: \(item as Any)")
        }
    }

    public func deleteItem(item: StorageReference) {
        item.delete { error in
            if let error {
                LogE("StorageManager: Error deleting item, \(error)")
            }
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
