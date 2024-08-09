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
    func fetchGroupMembers() {
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] members in
                guard let self else { return }
                self.members = members
            }.store(in: &cancelable)
    }

    func onMemberTap(_ memberId: String) {
        selectedMemberId = memberId
        router?.push(.GroupWhoGettingPaidView(groupId: groupId, selectedMemberId: memberId))
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupWhoIsPayingViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
