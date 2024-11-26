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

    func handleJoinMemberAction(completion: @escaping (Bool) -> Void) {
        Task {
            await joinMemberWithCode(completion: completion)
        }
    }

    private func joinMemberWithCode(completion: (Bool) -> Void) async {
        do {
            showLoader = true
            let code = try await codeRepository.fetchSharedCode(code: code)
            guard let code else {
                showLoader = false
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "The code you've entered is not exists."))
                return
            }
            await addMemberIfCodeExists(code: code)
            showLoader = false
            LogD("JoinMemberViewModel: \(#function) Member joined successfully.")
            completion(true)
        } catch {
            showLoader = false
            LogE("JoinMemberViewModel: \(#function) Failed to join member: \(error).")
            showToastForError()
            completion(false)
        }
    }

    private func addMemberIfCodeExists(code: SharedCode) async {
        let expireDate = code.expireDate.dateValue()
        let daysDifference = Calendar.current.dateComponents([.day], from: expireDate, to: Date()).day

        // Code will be valid until 2 days, so check for the day difference
        guard let daysDifference, daysDifference <= codeRepository.CODE_EXPIRATION_LIMIT else {
            showLoader = false
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "The code you've entered is expired."))
            return
        }

        await addMemberFor(code: code)
    }

    private func addMemberFor(code: SharedCode) async {
        guard let userId = preference.user?.id else {
            showLoader = false
            return
        }

        do {
            try await groupRepository.addMemberToGroup(groupId: code.groupId, memberId: userId)
            NotificationCenter.default.post(name: .joinGroup, object: code.groupId)
            try await codeRepository.deleteSharedCode(documentId: code.code)
            LogD("JoinMemberViewModel: \(#function) Member added successfully.")
        } catch {
            showLoader = false
            LogE("JoinMemberViewModel: \(#function) Failed to add member: \(error).")
            showToastForError()
        }
    }
}
