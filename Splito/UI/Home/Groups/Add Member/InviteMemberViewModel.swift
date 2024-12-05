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

    @Published private(set) var inviteCode = ""
    @Published var showShareSheet = false
    @Published private(set) var showLoader = false

    @Published var viewState: ViewState = .loading

    var group: Groups?
    private let groupId: String
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        self.fetchInitialData()
    }

    func fetchInitialData() {
        Task {
            await fetchGroup()
            await generateInviteCode()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            self.group = try await groupRepository.fetchGroupBy(id: groupId)
            viewState = .initial
            LogD("InviteMemberViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("InviteMemberViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    private func generateInviteCode() async {
        do {
            viewState = .loading
            inviteCode = inviteCode.randomString(length: 6).uppercased()
            let isAvailable = try await codeRepository.checkForCodeAvailability(code: inviteCode)
            if !isAvailable {
                await generateInviteCode()
            }
            viewState = .initial
            LogD("InviteMemberViewModel: \(#function) Invite code generated successfully.")
        } catch {
            LogE("InviteMemberViewModel: \(#function) Failed to generate invite code: \(error).")
            handleServiceError()
        }
    }

    func handleStoreShareCodeAction(completion: @escaping (Bool) -> Void) {
        Task {
            await storeSharedCode(completion: completion)
        }
    }

    private func storeSharedCode(completion: (Bool) -> Void) async {
        let shareCode = SharedCode(code: inviteCode.encryptHexCode(), groupId: groupId, expireDate: Timestamp())

        do {
            showLoader = true
            try await codeRepository.addSharedCode(sharedCode: shareCode)
            showLoader = false
            LogD("InviteMemberViewModel: \(#function) Shared code stored successfully.")
            completion(true)
        } catch {
            showLoader = false
            LogE("InviteMemberViewModel: \(#function) Failed to store shared code: \(error).")
            showToastForError()
            completion(false)
        }
    }

    // MARK: - User Actions
    func openShareSheet() {
        showShareSheet = true
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            viewState = .noInternet
        } else {
            viewState = .somethingWentWrong
        }
    }
}

// MARK: - View's State
extension InviteMemberViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
