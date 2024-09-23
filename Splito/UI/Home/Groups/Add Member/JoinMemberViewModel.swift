//
//  JoinMemberViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 13/03/24.
//

import Data
import BaseStyle

class JoinMemberViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var codeRepository: ShareCodeRepository

    @Published var code = ""
    @Published private(set) var showLoader: Bool = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func joinMemberWithCode() async -> Bool {
        do {
            showLoader = true
            let code = try await codeRepository.fetchSharedCode(code: code)
            guard let code else {
                showLoader = false
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "The code you've entered is not exists."))
                return false
            }
            return await addMemberIfCodeExists(code: code)
        } catch {
            showLoader = false
            showToastForError()
            return false
        }
    }

    private func addMemberIfCodeExists(code: SharedCode) async -> Bool {
        let expireDate = code.expireDate.dateValue()
        let daysDifference = Calendar.current.dateComponents([.day], from: expireDate, to: Date()).day

        // Code will be valid until 2 days, so check for the day difference
        guard let daysDifference, daysDifference <= codeRepository.CODE_EXPIRATION_LIMIT else {
            showLoader = false
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "The code you've entered is expired."))
            return false
        }

        return await addMemberFor(code: code)
    }

    private func addMemberFor(code: SharedCode) async -> Bool {
        guard let userId = preference.user?.id else { return false }

        do {
            try await groupRepository.addMemberToGroup(groupId: code.groupId, memberId: userId)
            NotificationCenter.default.post(name: .joinGroup, object: code.groupId)
            try await codeRepository.deleteSharedCode(documentId: code.code)
            showLoader = false
            return true
        } catch {
            showToastForError()
            return false
        }
    }
}
