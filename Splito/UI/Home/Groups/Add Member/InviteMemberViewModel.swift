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

        Task {
            await fetchGroup()
            await generateInviteCode()
        }
    }

    // MARK: - Data Loading
    private func generateInviteCode() async {
        inviteCode = inviteCode.randomString(length: 6).uppercased()

        do {
            let isAvailable = try await codeRepository.checkForCodeAvailability(code: inviteCode)
            if !isAvailable {
                await generateInviteCode()
            }
        } catch {
            showToastForError()
        }
    }

    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            self.group = group
        } catch {
            showToastForError()
        }
    }

    func storeSharedCode() async {
        let shareCode = SharedCode(code: inviteCode.encryptHexCode(), groupId: groupId, expireDate: Timestamp())

        do {
            try await codeRepository.addSharedCode(sharedCode: shareCode)
        } catch {
            showToastForError()
        }
    }

    // MARK: - User Actions
    func openShareSheet() {
        showShareSheet = true
    }
}
