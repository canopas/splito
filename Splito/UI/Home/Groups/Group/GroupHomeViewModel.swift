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

    @Published var overallOwingAmount = 0.0
    @Published var memberOwingAmount: [String: Double] = [:]

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
                guard let self, let userId = self.preference.user?.id else { return }

                self.expenses = expenses
                let queue = DispatchGroup()

                var owesToYou: [String: Double] = [:]
                var owedByYou: [String: Double] = [:]

                var expenseByYou = 0.0
                var combinedData: [ExpenseWithUser] = []

                for expense in expenses {
                    queue.enter()

                    let splitAmount = expense.amount / Double(expense.splitTo.count)

                    if expense.paidBy == userId {
                        expenseByYou += (expense.splitTo.count == 1 && !expense.splitTo.contains(userId)) ? expense.amount : expense.amount - splitAmount
                        for member in expense.splitTo where member != userId {
                            owesToYou[member, default: 0.0] += splitAmount
                        }
                    } else if expense.splitTo.contains(where: { $0 == userId }) {
                        expenseByYou -= splitAmount
                        owedByYou[expense.paidBy, default: 0.0] += splitAmount
                    }

                    self.fetchUserData(for: expense.paidBy) { user in
                        combinedData.append(ExpenseWithUser(expense: expense, user: user))
                        queue.leave()
                    }
                }

                queue.notify(queue: .main) {
                    owesToYou.forEach { userId, owesAmount in
                        self.memberOwingAmount[userId] = owesAmount
                    }
                    owedByYou.forEach { userId, owedAmount in
                        guard let owesAmount = self.memberOwingAmount[userId] else { return }
                        self.memberOwingAmount[userId] = owesAmount - owedAmount
                    }
                    self.expenseWithUser = combinedData
                    self.overallOwingAmount = expenseByYou
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
                     (expenses.isEmpty ? .noExpense : (overallOwingAmount == 0 ? .settledUp : .hasExpense)) :
                     (expenses.isEmpty ? .noMember : (overallOwingAmount == 0 ? .settledUp : .hasExpense))
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
