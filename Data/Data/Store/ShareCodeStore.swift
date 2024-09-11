//
//  ShareCodeStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestore

public class ShareCodeStore: ObservableObject {

    private let COLLECTION_NAME: String = "shared_codes"

    @Inject private var database: Firestore

    func addSharedCode(sharedCode: SharedCode) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                _ = try self.database.collection(self.COLLECTION_NAME).addDocument(from: sharedCode)
                promise(.success(()))
            } catch {
                LogE("ShareCodeStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error)))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchSharedCode(code: String) -> Future<SharedCode?, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(COLLECTION_NAME).whereField("code", isEqualTo: code).getDocuments(source: .server) { snapshot, error in
                if let error {
                    LogE("ShareCodeStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error)))
                    return
                }

                guard let document = snapshot?.documents.first else {
                    LogD("ShareCodeStore :: \(#function) The document is not available.")
                    promise(.success(nil))
                    return
                }

                do {
                    let sharedCode = try document.data(as: SharedCode.self)
                    promise(.success(sharedCode))
                } catch {
                    LogE("ShareCodeStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }
    }

    func deleteSharedCode(documentId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.COLLECTION_NAME).document(documentId).delete { error in
                if let error {
                    LogE("ShareCodeStore :: \(#function): Deleting data failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError(error: error)))
                } else {
                    LogD("ShareCodeStore :: \(#function): code deleted successfully.")
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }
}
