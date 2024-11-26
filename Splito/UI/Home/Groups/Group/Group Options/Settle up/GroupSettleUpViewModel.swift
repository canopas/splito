//
//  GroupSettleUpViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 03/06/24.
//

import Data
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
        fetchInitialViewData()
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroupDetails()
            await fetchGroupMembers()
        }
    }

    // MARK: - Data Loading
    func fetchGroupDetails() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                viewState = .initial
                return
            }
            self.group = group
            calculateMemberPayableAmount(group: group)
            viewState = .initial
            LogD("GroupSettleUpViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupSettleUpViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    func calculateMemberPayableAmount(group: Groups) {
        guard let userId = preference.user?.id else {
            viewState = .initial
            return
        }
        memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
    }

    private func fetchGroupMembers() async {
        guard let group, let userId = preference.user?.id else {
            viewState = .initial
            return
        }

        do {
            viewState = .loading
            self.members = try await groupRepository.fetchMembersBy(memberIds: group.members)
            self.members.removeAll(where: { $0.id == userId })
            viewState = .initial
            LogD("GroupSettleUpViewModel: \(#function) Group members fetched successfully.")
        } catch {
            LogE("GroupSettleUpViewModel: \(#function) Failed to fetch group members: \(error).")
            handleServiceError()
        }
    }

    // MARK: - Helper Methods
    func getMembersBalance(memberId: String) -> Double {
        guard let group else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return 0
        }

        if let index = group.balances.firstIndex(where: { $0.id == memberId }) {
            return group.balances[index].balance
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
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            viewState = .noInternet
        } else {
            viewState = .somethingWentWrong
        }
    }
}

// MARK: - View States
extension GroupSettleUpViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
