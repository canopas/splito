//
//  Query+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 22/05/24.
//

import Combine
import FirebaseFirestore

extension Query {
    func getDocuments<T>(as type: T.Type) async throws -> (data: [T], lastDocument: DocumentSnapshot?) where T: Decodable {
        let snapshot = try await self.getDocuments(source: .server)

        let data = try snapshot.documents.map({ document in
            try document.data(as: T.self)
        })

        return (data, snapshot.documents.last)
    }

    func addSnapshotListener<T>(as type: T.Type) -> AnyPublisher<[T], ServiceError> where T: Decodable {
        let publisher = PassthroughSubject<[T], ServiceError>()

        /// includeMetadataChanges: false: This option ensures that your listener will only be triggered by actual data changes, not by metadata changes (like network acknowledgment or pending writes).
        let listener = self.addSnapshotListener(includeMetadataChanges: false) { querySnapshot, error in
            if let error {
                LogE("SnapshotPublisher :: error: \(error.localizedDescription)")
                publisher.send(completion: .failure(.databaseError(error: error)))
                return
            }

            guard let documents = querySnapshot?.documents else {
                LogE("SnapshotPublisher :: The document is not available.")
                publisher.send(completion: .finished)
                return
            }

            do {
                let decodedDocuments = try documents.compactMap { document in
                    try document.data(as: T.self)
                }
                publisher.send(decodedDocuments)
            } catch {
                LogE("SnapshotPublisher :: Decode error: \(error.localizedDescription)")
                publisher.send(completion: .failure(.decodingError))
            }
        }

        return publisher
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }
}
