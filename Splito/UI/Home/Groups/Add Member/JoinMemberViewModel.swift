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

    func joinMemberWithCode(completion: @escaping () -> Void) async {
        showLoader = true

        do {
            let code = try await codeRepository.fetchSharedCode(code: code)
            guard let code else {
                self.showLoader = false
                self.showToastFor(toast: ToastPrompt(type: .error, title: "Error",
                                                     message: "The code you've entered is not exists."))
                return
            }
            await self.addMemberIfCodeExists(code: code)
        } catch {
            self.showLoader = false
            self.showToastFor(error as! ServiceError)
            handleServiceError(error as! ServiceError)
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

        await addMember(groupId: code.groupId)
        self.showLoader = false

        do {
            _ = try await codeRepository.deleteSharedCode(documentId: code.id ?? "")
        } catch {
            showToastFor(error as! ServiceError)
        }
    }

    private func addMember(groupId: String) async {
        guard let userId = preference.user?.id else { return }

        do {
            try await groupRepository.addMemberToGroup(groupId: groupId, memberId: userId)
            NotificationCenter.default.post(name: .joinGroup, object: groupId)
        } catch {
            showToastFor(error as! ServiceError)
        }
    }
}
