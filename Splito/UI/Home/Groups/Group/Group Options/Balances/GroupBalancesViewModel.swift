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

    @Published var viewState: ViewState = .loading

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

        NotificationCenter.default.addObserver(self, selector: #selector(handleAddTransaction(notification:)), name: .addTransaction, object: nil)

        fetchInitialBalancesData()
    }

    func fetchInitialBalancesData() {
        Task { [weak self] in
            await self?.fetchGroupWithMembers()
        }
    }

    // MARK: - Data Loading
    func fetchGroupWithMembers() async {
        do {
            self.group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                viewState = .initial
                return
            }
            groupMemberData = try await groupRepository.fetchMembersBy(memberIds: group.members)
            calculateExpensesSimplified()
            viewState = .initial
            LogD("GroupBalancesViewModel: \(#function) Group with members fetched successfully.")
        } catch {
            LogE("GroupBalancesViewModel: \(#function) Failed to fetch group with members: \(error).")
            handleServiceError()
        }
    }

    // MARK: - Helper Methods
    private func calculateExpensesSimplified() {
        guard let group else {
            viewState = .initial
            LogE("GroupBalancesViewModel :: \(#function) group not found.")
            return
        }

        let filteredBalances = group.balances.filter { group.members.contains($0.id) }

        let memberBalances = filteredBalances.flatMap { balance in
            balance.balanceByCurrency.map { (currency, balanceDetails) in
                // Create a combined balance for each currency
                MembersCombinedBalance(id: balance.id, totalOwedAmount: [currency: balanceDetails.balance],
                                       balances: [currency: [balance.id: balanceDetails.balance]])
            }
        }

        // Calculate settlements between group members
        let settlements = calculateSettlements(balances: filteredBalances)

        // Merge settlements with member balances
        let combinedBalances = settlements.reduce(into: memberBalances) { balances, settlement in
            // Find sender and receiver indices in the balances list
            if let senderIndex = balances.firstIndex(where: { $0.id == settlement.sender }),
               let receiverIndex = balances.firstIndex(where: { $0.id == settlement.receiver }) {

                // Handle sender's balance update
                if balances[senderIndex].balances[settlement.currency] != nil {
                    // If currency balance exists for sender, subtract the settlement amount
                    balances[senderIndex].balances[settlement.currency]?[settlement.receiver, default: 0.0] -= settlement.amount
                } else {
                    // If no balance exists, initialize the currency balance for the sender
                    balances[senderIndex].balances[settlement.currency] = [settlement.receiver: -settlement.amount]
                }

                // Handle receiver's balance update
                if balances[receiverIndex].balances[settlement.currency] != nil {
                    balances[receiverIndex].balances[settlement.currency]?[settlement.sender, default: 0.0] += settlement.amount
                } else {
                    balances[receiverIndex].balances[settlement.currency] = [settlement.sender: settlement.amount]
                }
            }
        }

        self.sortMemberBalances(memberBalances: combinedBalances)
    }

    private func sortMemberBalances(memberBalances: [MembersCombinedBalance]) {
        guard let userId = preference.user?.id,
              let userIndex = memberBalances.firstIndex(where: { $0.id == userId }) else {
            viewState = .initial
            return
        }

        var sortedMembers = memberBalances

        var userBalance = sortedMembers.remove(at: userIndex)
        userBalance.isExpanded = userBalance.totalOwedAmount.values.reduce(0, +) != 0
        sortedMembers.insert(userBalance, at: 0)

        sortedMembers.sort { member1, member2 in
            if member1.id == userId { true } else if member2.id == userId { false } else { getMemberName(id: member1.id) < getMemberName(id: member2.id) }
        }

        self.memberBalances = sortedMembers
    }

    private func getMemberDataBy(id: String) -> AppUser? {
        return groupMemberData.first(where: { $0.id == id })
    }

    func getMemberImage(id: String) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return member.imageUrl ?? ""
    }

    func getMemberName(id: String, needFullName: Bool = false) -> String {
        guard let userId = preference.user?.id, let member = getMemberDataBy(id: id) else { return "" }
        return needFullName ? (id == userId ? "You" : member.fullName) : (id == userId ? "you" : member.nameWithLastInitial)
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

    @objc private func handleAddTransaction(notification: Notification) {
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully."))
        Task { [weak self] in
            await self?.fetchGroupWithMembers()
        }
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

// MARK: - Struct to hold combined expense and user owe amount
struct MembersCombinedBalance {
    let id: String
    var isExpanded: Bool = false
    var totalOwedAmount: [String: Double] = [:]
    var balances: [String: [String: Double]] = [:]
}

// MARK: - View States
extension GroupBalancesViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
