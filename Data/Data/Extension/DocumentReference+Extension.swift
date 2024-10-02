//
//  DocumentReference+Extension.swift
//  Data
//
//  Created by Amisha Italiya on 06/09/24.
//

import Combine
import FirebaseFirestore

extension DocumentReference {
//    func getDocument<T: Decodable>(as type: T.Type) async throws -> T? {
//        let documentSnapshot = try await self.getDocument()
//        
//        guard documentSnapshot.exists else {
//            return nil // or throw an error if needed
//        }
//        
//        return try documentSnapshot.data(as: T.self)
//    }

    func toAnyPublisher<T: Decodable>() -> AnyPublisher<T?, ServiceError> {
        let subject = CurrentValueSubject<T?, ServiceError>(nil)

        let listener = addSnapshotListener(includeMetadataChanges: false) { documentSnapshot, error in
            if let error {
                subject.send(completion: .failure(.databaseError(error: error)))
                return
            }

            guard let document = documentSnapshot else {
                subject.send(nil)  // No document found, send nil.
                return
            }

            do {
                let data = try document.data(as: T.self)
                subject.send(data)
            } catch {
                subject.send(completion: .failure(.decodingError))
            }
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }
}
