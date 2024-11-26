//
//  GroupWhoIsPayingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Foundation

class GroupWhoIsPayingViewModel: BaseViewModel, ObservableObject {

    @Inject private var groupRepository: GroupRepository

    @Published private(set) var members: [AppUser] = []
    @Published private(set) var currentViewState: ViewState = .loading

    @Published private(set) var selectedMemberId: String?
    @Published private(set) var isPaymentSettled: Bool

    private let groupId: String
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>? = nil, groupId: String, isPaymentSettled: Bool) {
        self.groupId = groupId
        self.isPaymentSettled = isPaymentSettled
        self.router = router
        super.init()
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroupWithMembers()
        }
    }

    // MARK: - Data Loading
    private func fetchGroupWithMembers() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                currentViewState = .initial
                return
            }
            self.members = try await groupRepository.fetchMembersBy(memberIds: group.members)
            currentViewState = .initial
            LogD("GroupWhoIsPayingViewModel: \(#function) Group with members fetched successfully.")
        } catch {
            LogE("GroupWhoIsPayingViewModel: \(#function) Failed to fetch group with members: \(error).")
            handleServiceError()
        }
    }

    func onMemberTap(_ memberId: String) {
        selectedMemberId = memberId
        router?.push(.GroupWhoGettingPaidView(groupId: groupId, selectedMemberId: memberId))
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
        }
    }
}

// MARK: - View States
extension GroupWhoIsPayingViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
