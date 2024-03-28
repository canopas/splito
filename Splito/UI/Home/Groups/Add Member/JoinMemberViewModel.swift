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
    @Published private(set) var currentState: ViewState = .initial

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }

    func joinMemberWithCode() {
        currentState = .loading
        codeRepository.fetchSharedCode(code: code)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    self?.currentState = .initial
                    self?.showToastFor(error)
                case .finished:
                    self?.currentState = .initial
                }
            } receiveValue: { [weak self] code in
                guard let self else { return }

                guard let code else {
                    self.showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Entered code not exists."))
                    return
                }

                self.addMemberIfCodeExists(code: code)
            }.store(in: &cancelables)
    }

    func addMemberIfCodeExists(code: SharedCode) {
        let expireDate = code.expireDate.dateValue()
        let daysDifference = Calendar.current.dateComponents([.day], from: expireDate, to: Date()).day

        // Code will be valid until 2 days, so check for the day difference
        guard let daysDifference, daysDifference <= codeRepository.CODE_EXPIRATION_LIMIT else {
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Entered code is expired."))
            return
        }

        addMember(groupId: code.groupId) {
            _ = self.codeRepository.deleteSharedCode(documentId: code.id ?? "")
            self.goToGroupHome()
        }
    }

    func addMember(groupId: String, completion: @escaping () -> Void) {
        guard let userId = preference.user?.id else { return }
        currentState = .loading

        groupRepository.addMemberToGroup(memberId: userId, groupId: groupId)
            .sink { [weak self] result in
                if case .failure(let error) = result {
                    self?.currentState = .initial
                    self?.showToastFor(error)
                    completion()
                }
            } receiveValue: { _ in
                self.currentState = .initial
                completion()
            }.store(in: &cancelables)
    }

    func goToGroupHome() {
        self.router.pop()
    }
}

// MARK: - View's State
extension JoinMemberViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
