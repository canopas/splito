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

    func addSharedCode(sharedCode: SharedCode) async throws {
        do {
            try database.collection(self.COLLECTION_NAME).addDocument(from: sharedCode)
        } catch {
            LogE("ShareCodeStore :: \(#function) error: \(error.localizedDescription)")
            throw ServiceError.databaseError(error: error)
        }
    }

    func fetchSharedCode(code: String) async throws -> SharedCode? {
        let snapshot = try await self.database.collection(COLLECTION_NAME)
            .whereField("code", isEqualTo: code)
            .getDocuments(source: .server)

        // Check for documents and decode the first one
        guard let document = snapshot.documents.first else {
            LogD("ShareCodeStore :: \(#function) The document is not available.")
            return nil
        }

        let sharedCode = try document.data(as: SharedCode.self)
        return sharedCode
    }

    func deleteSharedCode(documentId: String) async throws {
        do {
            try await database.collection(self.COLLECTION_NAME).document(documentId).delete()
        } catch {
            LogE("ShareCodeStore :: \(#function): Deleting data failed with error: \(error.localizedDescription).")
            throw ServiceError.databaseError(error: error)
        }
    }
}
