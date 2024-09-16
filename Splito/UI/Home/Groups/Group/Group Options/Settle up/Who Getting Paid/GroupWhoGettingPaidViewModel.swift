//
//  GroupWhoGettingPaidViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Combine

class GroupWhoGettingPaidViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var members: [AppUser] = []
    @Published var viewState: ViewState = .initial

    @Published private(set) var payerId: String
    @Published private(set) var selectedMemberId: String?

    private let groupId: String
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>? = nil, groupId: String, payerId: String) {
        self.router = router
        self.groupId = groupId
        self.payerId = payerId
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

    func onMemberTap(memberId: String) {
        selectedMemberId = memberId
        router?.push(.GroupPaymentView(transactionId: nil, groupId: groupId, payerId: payerId, receiverId: memberId, amount: 0))
    }
}

// MARK: - View States
extension GroupWhoGettingPaidViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
