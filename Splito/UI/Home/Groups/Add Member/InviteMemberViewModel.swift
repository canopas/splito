//
//  InviteMemberViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 11/03/24.
//

import Data
import BaseStyle
import FirebaseFirestoreInternal

class InviteMemberViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository
    @Inject var codeRepository: ShareCodeRepository

    @Published var inviteCode = ""
    @Published var showShareSheet = false

    var group: Groups?
    private let groupId: String
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId

        super.init()

        self.generateInviteCode()
        self.fetchGroup()
    }

    func generateInviteCode() {
        inviteCode = inviteCode.randomString(length: 6).uppercased()
        codeRepository.checkForCodeAvailability(code: inviteCode) { [weak self] isAvailable in
            if let self, !isAvailable {
                self.generateInviteCode()
            }
        }
    }

    func fetchGroup() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
            }.store(in: &cancelable)
    }

    func storeSharedCode() {
        let shareCode = SharedCode(code: inviteCode.encryptHexCode(), groupId: groupId, expireDate: Timestamp())
        codeRepository.addSharedCode(sharedCode: shareCode) { [weak self] id in
            if id != nil {
                self?.router.pop()
            }
        }
    }
}
