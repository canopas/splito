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
        super.init()
    }

    func joinMemberWithCode() {
        showLoader = true
        codeRepository.fetchSharedCode(code: code)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showLoader = false
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] code in
                guard let self else { return }
                guard let code else {
                    self.showLoader = false
                    self.showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Entered code not exists."))
                    return
                }
                self.addMemberIfCodeExists(code: code)
            }.store(in: &cancelable)
    }

    private func addMemberIfCodeExists(code: SharedCode) {
        let expireDate = code.expireDate.dateValue()
        let daysDifference = Calendar.current.dateComponents([.day], from: expireDate, to: Date()).day

        // Code will be valid until 2 days, so check for the day difference
        guard let daysDifference, daysDifference <= codeRepository.CODE_EXPIRATION_LIMIT else {
            showLoader = false
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Entered code is expired."))
            return
        }

        addMember(groupId: code.groupId) {
            self.showLoader = false
            _ = self.codeRepository.deleteSharedCode(documentId: code.id ?? "")
            self.goToGroupHome()
        }
    }

    private func addMember(groupId: String, completion: @escaping () -> Void) {
        guard let userId = preference.user?.id else { return }

        groupRepository.addMemberToGroup(memberId: userId, groupId: groupId)
            .sink { [weak self] result in
                if case .failure(let error) = result {
                    self?.showToastFor(error)
                    completion()
                }
            } receiveValue: { _ in
                completion()
            }.store(in: &cancelable)
    }

    private func goToGroupHome() {
        self.router.pop()
    }
}
