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
    func fetchGroupMembers() {
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] members in
                self?.members = members
            }.store(in: &cancelable)
    }

    func onMemberTap(memberId: String) {
        selectedMemberId = memberId
        router?.push(.GroupPaymentView(transactionId: nil, groupId: groupId, payerId: payerId, receiverId: memberId, amount: 0))
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupWhoGettingPaidViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
