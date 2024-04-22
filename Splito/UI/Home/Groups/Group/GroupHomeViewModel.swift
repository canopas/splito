//
//  GroupHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data
import SwiftUI

class GroupHomeViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var expenses: [Expense] = []
    @Published var expenseWithUser: [ExpenseWithUser] = []
    @Published var groupState: GroupState = .noMember

    @Published var totalGroupMember = 1
    @Published var groupTotalExpense = 0.0
    @Published var overallOwingAmount = 0.0
    @Published var memberOwingAmounts: [String: Double] = [:]

    @Published var amountOwesToYou: [String: Double] = [:]
    @Published var amountOwedByYou: [String: Double] = [:]

    var group: Groups?
    private let groupId: String
    private var groupUserData: [AppUser] = []
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId

        super.init()

        fetchGroupAndExpenses()
    }

    func fetchGroupAndExpenses() {
        groupState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.totalGroupMember = group.members.count

                for member in group.members where member != self.preference.user?.id {
                    self.fetchUserData(for: member) { memberData in
                        self.groupUserData.append(memberData)
                    }
                }
                self.fetchExpenses()
            }.store(in: &cancelable)
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return groupUserData.first(where: { $0.id == id })
    }

    func fetchExpenses() {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self, let group = self.group, let userId = self.preference.user?.id else { return }

                self.expenses = expenses
                let queue = DispatchGroup()

                var owesToYou = 0.0
                var owedByYou: [String: Double] = [:]

                var expenseByYou = 0.0
                var allGroupMembers = Set<String>()
                var combinedData: [ExpenseWithUser] = []

                for expense in expenses {
                    queue.enter()

                    self.groupTotalExpense += expense.amount
                    let splitAmount = expense.amount / Double(expense.splitTo.count)

                    if expense.paidBy == userId {
                        owesToYou += splitAmount
                        expenseByYou += expense.amount
                    } else {
                        owedByYou[expense.paidBy, default: 0.0] += splitAmount
                    }

                    allGroupMembers.formUnion(expense.splitTo)
                    allGroupMembers.insert(expense.paidBy)

                    self.fetchUserData(for: expense.paidBy) { user in
                        combinedData.append(ExpenseWithUser(expense: expense, user: user))
                        queue.leave()
                    }
                }

                allGroupMembers.subtract([userId])
                allGroupMembers.subtract(owedByYou.keys)

                allGroupMembers.forEach { owedByYou[$0] = 0.0 }

                // Notify when all fetch operations are complete
                queue.notify(queue: .main) {
                    owedByYou.forEach { userId, owedAmount in
                        let oweAmount = owesToYou - owedAmount
                        if oweAmount < 0 {
                            self.amountOwedByYou[userId] = abs(oweAmount)
                        } else if oweAmount > 0 {
                            self.amountOwesToYou[userId] = oweAmount
                        }
                    }
                    self.expenseWithUser = combinedData
                    self.overallOwingAmount = expenseByYou - (group.members.count > 1 ? self.groupTotalExpense / Double(group.members.count) : 0)
                    self.setGroupViewState()
                }
            }.store(in: &cancelable)
    }

    func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    func setGroupViewState() {
        guard let group else { return }
        groupState = group.members.count > 1 ?
                     (expenses.isEmpty ? .noExpense : (groupTotalExpense == overallOwingAmount && overallOwingAmount != 0 ? .settledUp : .hasExpense)) :
                     (expenses.isEmpty ? .noMember : (groupTotalExpense == overallOwingAmount && overallOwingAmount != 0 ? .settledUp : .hasExpense))
    }

    func setHasExpenseState() {
        groupState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.groupState = .hasExpense
        }
    }

    func handleCreateGroupClick() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleAddMemberClick() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleSettingButtonTap() {
        router.push(.GroupSettingView(groupId: groupId))
    }

    func  handleExpenseItemTap(expenseId: String) {
        router.push(.ExpenseDetailView(expenseId: expenseId))
    }
}

// MARK: - Group State
extension GroupHomeViewModel {
    enum GroupState {
        case loading
        case noMember
        case noExpense
        case settledUp
        case hasExpense
    }
}

// Struct to hold combined expense and user information
struct ExpenseWithUser: Hashable {
    let expense: Expense
    let user: AppUser
}
