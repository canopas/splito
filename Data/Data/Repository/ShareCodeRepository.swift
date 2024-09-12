//
//  ShareCodeRepository.swift
//  Data
//
//  Created by Amisha Italiya on 12/03/24.
//

import Combine

public class ShareCodeRepository: ObservableObject {

    public let CODE_EXPIRATION_LIMIT = 2 /// Limit for code expiration, in days.

    @Inject private var store: ShareCodeStore

    private var cancelable = Set<AnyCancellable>()

    public func addSharedCode(sharedCode: SharedCode) async throws {
        try await store.addSharedCode(sharedCode: sharedCode)
    }

    public func fetchSharedCode(code: String) async throws -> SharedCode? {
        try await store.fetchSharedCode(code: code.encryptHexCode())
    }

    public func deleteSharedCode(documentId: String) async throws {
        try await store.deleteSharedCode(documentId: documentId)
    }

    public func checkForCodeAvailability(code: String) async throws -> Bool {
        let fetchedCode = try await fetchSharedCode(code: code)
        return fetchedCode == nil
    }
}
