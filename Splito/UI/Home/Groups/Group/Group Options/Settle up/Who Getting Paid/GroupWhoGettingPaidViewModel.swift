//
//  GroupWhoGettingPaidViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Foundation

class GroupWhoGettingPaidViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var members: [AppUser] = []
    @Published var viewState: ViewState = .loading

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

    func fetchInitialMembersData() {
        Task {
            await fetchGroupMembers()
        }
    }

    // MARK: - Data Loading
    private func fetchGroupMembers() async {
        do {
            let members = try await groupRepository.fetchMembersBy(groupId: groupId)
            self.members = members
            viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func onMemberTap(memberId: String) {
        selectedMemberId = memberId
        router?.push(.GroupPaymentView(transactionId: nil, groupId: groupId, payerId: payerId, receiverId: memberId, amount: 0))
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

// MARK: - View States
extension GroupWhoGettingPaidViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
