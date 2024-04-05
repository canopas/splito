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

    public func uploadImage(for storeType: ImageStoreType, id: String, imageData: Data) -> AnyPublisher<String, ServiceError> {
        let storageRef = storage.reference(withPath: "/\(storeType.pathName)/\(id)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg"

        return Future { promise in
            storageRef.putData(imageData, metadata: metadata) { _, error in
                if let error {
                    LogE("StorageManager: Error while uploading file: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
                } else {
                    storageRef.downloadURL { url, error in
                        if let error {
                            LogE("StorageManager: Download url failed with error: \(error.localizedDescription)")
                            promise(.failure(.databaseError))
                        } else if let imageUrl = url?.absoluteString {
                            LogD("StorageManager: Image successfully uploaded to Firebase!")
                            promise(.success(imageUrl))
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    public func updateImage(for type: ImageStoreType, id: String, url: String, imageData: Data) -> AnyPublisher<String, ServiceError> {
        self.deleteImage(imageUrl: url)
            .flatMap { _ in
                self.uploadImage(for: type, id: id, imageData: imageData)
            }
            .eraseToAnyPublisher()
    }

    public func deleteImage(imageUrl: String) -> AnyPublisher<Void, ServiceError> {
        let storageRef = storage.reference(forURL: imageUrl)

        return Future { promise in
            storageRef.delete { error in
                if let error {
                    LogE("StorageManager: Error while deleting image: \(error)")
                    promise(.failure(.databaseError))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
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
