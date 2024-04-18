//
//  ShareCodeStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestoreInternal

public class ShareCodeStore: ObservableObject {

    private let DATABASE_NAME: String = "shared_codes"

    @Inject private var database: Firestore

    func addSharedCode(sharedCode: SharedCode) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                let documentRef = try self.database.collection(self.DATABASE_NAME).addDocument(from: sharedCode)
                promise(.success(()))
            } catch {
                LogE("ShareCodeStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
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

            self.database.collection(DATABASE_NAME).whereField("code", isEqualTo: code).getDocuments { snapshot, error in
                if let error {
                    LogE("ShareCodeStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError))
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

            self.database.collection(self.DATABASE_NAME).document(documentId).delete { error in
                if let error {
                    LogE("ShareCodeStore :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError))
                } else {
                    LogD("ShareCodeStore :: \(#function): code deleted successfully.")
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }
}
