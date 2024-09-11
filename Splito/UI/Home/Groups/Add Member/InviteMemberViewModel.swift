//
//  InviteMemberViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 11/03/24.
//

import Data
import BaseStyle
import FirebaseFirestore

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

        fetchGroup()
        generateInviteCode()
    }

    // MARK: - Data Loading
    private func generateInviteCode() {
        inviteCode = inviteCode.randomString(length: 6).uppercased()
        codeRepository.checkForCodeAvailability(code: inviteCode)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] isAvailable in
                if let self, !isAvailable {
                    self.generateInviteCode()
                }
            }.store(in: &cancelable)
    }

    private func fetchGroup() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
            }.store(in: &cancelable)
    }

    func storeSharedCode(completion: @escaping () -> Void) {
        let shareCode = SharedCode(code: inviteCode.encryptHexCode(), groupId: groupId, expireDate: Timestamp())
        codeRepository.addSharedCode(sharedCode: shareCode)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { _ in
                completion()
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func openShareSheet() {
        showShareSheet = true
    }
}
