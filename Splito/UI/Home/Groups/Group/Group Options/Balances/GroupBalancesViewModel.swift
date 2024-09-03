//
//  GroupBalancesViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 26/04/24.
//

import Data
import SwiftUI

class GroupBalancesViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var viewState: ViewState = .initial

    @Published var groupId: String
    @Published var showSettleUpSheet: Bool = false
    @Published var memberBalances: [MembersCombinedBalance] = []

    @Published var payerId: String?
    @Published var receiverId: String?
    @Published var amount: Double?

    private var groupMemberData: [AppUser] = []
    let router: Router<AppRoute>
    var group: Groups?

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        fetchGroupMembers()
    }

    // MARK: - Data Loading
    func fetchGroupMembers() {
        viewState = .loading
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { users in
                self.groupMemberData = users
                self.fetchGroupAndExpenses()
            }.store(in: &cancelable)
    }

    private func fetchGroupAndExpenses() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.calculateExpensesSimplified(group: group)
            }.store(in: &cancelable)
    }

    // MARK: - Helper Methods
    private func calculateExpensesSimplified(group: Groups) {
        let memberBalances = group.balances.map {
            MembersCombinedBalance(id: $0.id, totalOwedAmount: $0.balance)
        }

        // Create group member balances for settlements
        let groupMemberBalances = group.balances.map {
            GroupMemberBalance(id: $0.id, balance: $0.balance, totalSummary: $0.totalSummary)
        }

        // Calculate settlements between group members
        let settlements = calculateSettlements(balances: groupMemberBalances)

        // Merge settlements with member balances
        let combinedBalances = settlements.reduce(into: memberBalances) { balances, settlement in
            let senderIndex = balances.firstIndex { $0.id == settlement.sender }
            let receiverIndex = balances.firstIndex { $0.id == settlement.receiver }

            if let senderIndex = senderIndex {
                balances[senderIndex].balances[settlement.receiver, default: 0.0] -= settlement.amount
            }

            if let receiverIndex = receiverIndex {
                balances[receiverIndex].balances[settlement.sender, default: 0.0] += settlement.amount
            }
        }

        DispatchQueue.main.async {
            self.sortMemberBalances(memberBalances: combinedBalances)
        }
    }

    private func sortMemberBalances(memberBalances: [MembersCombinedBalance]) {
        guard let userId = preference.user?.id, let userIndex = memberBalances.firstIndex(where: { $0.id == userId }) else { return }

        var sortedMembers = memberBalances

        var userBalance = sortedMembers.remove(at: userIndex)
        userBalance.isExpanded = userBalance.totalOwedAmount != 0
        sortedMembers.insert(userBalance, at: 0)

        sortedMembers.sort { member1, member2 in
            if member1.id == userId { true } else if member2.id == userId { false } else { getMemberName(id: member1.id) < getMemberName(id: member2.id) }
        }

        self.memberBalances = sortedMembers
        viewState = .initial
    }

    private func getMemberDataBy(id: String) -> AppUser? {
        return groupMemberData.first(where: { $0.id == id })
    }

    func getMemberImage(id: String) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return member.imageUrl ?? ""
    }

    func getMemberName(id: String, needFullName: Bool = false) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return needFullName ? member.fullName : member.nameWithLastInitial
    }

    // MARK: - User Actions
    func handleBalanceExpandView(id: String) {
        if let index = memberBalances.firstIndex(where: { $0.id == id }) {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                memberBalances[index].isExpanded.toggle()
            }
        }
    }

    func handleSettleUpTap(payerId: String, receiverId: String, amount: Double) {
        self.payerId = payerId
        self.receiverId = receiverId
        self.amount = amount
        showSettleUpSheet = true
    }

    func dismissSettleUpSheet() {
        showSettleUpSheet = false
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully"))
    }
}

// MARK: - Struct to hold combined expense and user owe amount
struct MembersCombinedBalance {
    let id: String
    var isExpanded: Bool = false
    var totalOwedAmount: Double = 0
    var balances: [String: Double] = [:]
}

// MARK: - View States
extension GroupBalancesViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
