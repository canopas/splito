//
//  GroupWhoIsPayingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Combine

class GroupWhoIsPayingViewModel: BaseViewModel, ObservableObject {

    @Inject private var groupRepository: GroupRepository

    @Published private(set) var members: [AppUser] = []
    @Published private(set) var viewState: ViewState = .initial

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

    // MARK: - Data Loading
    func fetchGroupMembers() async {
        do {
            let members = try await groupRepository.fetchMembersBy(groupId: groupId)
            self.members = members
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    func onMemberTap(_ memberId: String) {
        selectedMemberId = memberId
        router?.push(.GroupWhoGettingPaidView(groupId: groupId, selectedMemberId: memberId))
    }
}

// MARK: - View States
extension GroupWhoIsPayingViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
