//
//  Query+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 22/05/24.
//

import Combine
import FirebaseFirestore

extension Query {
    func snapshotPublisher<T: Decodable>(as type: T.Type) -> AnyPublisher<[T], ServiceError> {
        let subject = PassthroughSubject<[T], ServiceError>()

        /// includeMetadataChanges: false: This option ensures that your listener will only be triggered by actual data changes, not by metadata changes (like network acknowledgment or pending writes).
        let listener = addSnapshotListener(includeMetadataChanges: false) { querySnapshot, error in
            if let error = error {
                LogE("SnapshotPublisher :: error: \(error.localizedDescription)")
                subject.send(completion: .failure(.databaseError(error: error.localizedDescription)))
                return
            }

            guard let documents = querySnapshot?.documents else {
                LogE("SnapshotPublisher :: The document is not available.")
                subject.send(completion: .finished)
                return
            }

            do {
                let decodedDocuments = try documents.compactMap { document in
                    try document.data(as: T.self)
                }
                subject.send(decodedDocuments)
            } catch {
                LogE("SnapshotPublisher :: Decode error: \(error.localizedDescription)")
                subject.send(completion: .failure(.decodingError))
            }
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }
}

extension DocumentReference {
    func toAnyPublisher<T: Decodable>() -> AnyPublisher<T?, Error> {
        let subject = CurrentValueSubject<T?, Error>(nil)

        let listener = addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                subject.send(completion: .failure(error!))
                return
            }

            guard let data = try? document.data(as: T.self) else {
                subject.send(nil)
                return
            }
            subject.send(data)
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }
}
