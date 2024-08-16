//
//  GroupSettleUpViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 03/06/24.
//

import Data
import Combine
import SwiftUI

class GroupSettleUpViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository

    @Published private(set) var viewState: ViewState = .loading
    @Published private(set) var memberOwingAmount: [String: Double] = [:]

    private var group: Groups?
    private var members: [AppUser] = []

    private let groupId: String
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>? = nil, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        fetchGroupDetails()
    }

    // MARK: - Data Loading
    private func fetchGroupDetails() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.calculateMemberPayableAmount(group: group)
                self.fetchGroupMembers()
            }.store(in: &cancelable)
    }

    func calculateMemberPayableAmount(group: Groups) {
        guard let userId = self.preference.user?.id else { return }
        memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balance)
    }

    private func fetchGroupMembers() {
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] members in
                guard let self, let userId = preference.user?.id else { return }
                self.members = members
                self.members.removeAll(where: { $0.id == userId })
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    // MARK: - Helper Methods

    func getMembersBalance(memberId: String) -> Double {
        guard let group else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return 0
        }

        if let index = group.balance.firstIndex(where: { $0.id == memberId }) {
            return group.balance[index].balance
        }

        return 0
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    // MARK: - User Actions
    func handleMoreButtonTap() {
        router?.push(.GroupWhoIsPayingView(groupId: groupId, isPaymentSettled: false))
    }

    func onMemberTap(memberId: String, amount: Double) {
        guard let userId = self.preference.user?.id else { return }
        let (payerId, receiverId) = amount < 0 ? (userId, memberId) : (memberId, userId)

        router?.push(.GroupPaymentView(transactionId: nil, groupId: groupId,
                                       payerId: payerId, receiverId: receiverId, amount: amount))
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupSettleUpViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
