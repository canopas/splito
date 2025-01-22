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
    @Published private(set) var memberOwingAmount: [CombineMemberOwingAmount] = []

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
        Task { [weak self] in
            await self?.fetchGroupDetails()
            await self?.fetchGroupMembers()
        }
    }

    // MARK: - Data Loading
    func fetchGroupDetails() async {
        do {
            group = try await groupRepository.fetchGroupBy(id: groupId)
            calculateMemberPayableAmount()
            viewState = .initial
            LogD("GroupSettleUpViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupSettleUpViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    func calculateMemberPayableAmount() {
        guard let group, let userId = preference.user?.id else {
            viewState = .initial
            return
        }
        let memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
        self.memberOwingAmount = memberOwingAmount.flatMap { (currency, balance) in
            balance.map { CombineMemberOwingAmount(memberId: $0.key, balance: $0.value, currencyCode: currency) }
        }
    }

    private func fetchGroupMembers() async {
        guard let group, let userId = preference.user?.id else {
            viewState = .initial
            return
        }

        do {
            viewState = .loading
            members = try await groupRepository.fetchMembersBy(memberIds: group.members)
            members.removeAll(where: { $0.id == userId })
            viewState = .initial
            LogD("GroupSettleUpViewModel: \(#function) Group members fetched successfully.")
        } catch {
            LogE("GroupSettleUpViewModel: \(#function) Failed to fetch group members: \(error).")
            handleServiceError()
        }
    }

    // MARK: - Helper Methods
    func getMemberDataBy(id: String) -> AppUser? {
        members.first(where: { $0.id == id })
    }

    // MARK: - User Actions
    func handleMoreButtonTap() {
        router?.push(.GroupWhoIsPayingView(groupId: groupId, isPaymentSettled: false))
    }

    func onMemberTap(memberBalance: CombineMemberOwingAmount) {
        guard let userId = self.preference.user?.id else { return }
        let (payerId, receiverId) = memberBalance.balance < 0 ? (userId, memberBalance.memberId) : (memberBalance.memberId, userId)

        router?.push(.GroupPaymentView(transactionId: nil, groupId: groupId,
                                       payerId: payerId, receiverId: receiverId, amount: memberBalance.balance,
                                       currency: memberBalance.currencyCode))
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

struct CombineMemberOwingAmount: Hashable {
    let id = UUID()
    let memberId: String
    let balance: Double
    let currencyCode: String
}
