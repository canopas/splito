//
//  GroupListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import Data

class GroupListViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var currentViewState: ViewState = .initial
    @Published var groupListState: GroupListState = .noGroup

    @Published var showGroupMenu = false
    @Published var usersTotalExpense = 0.0

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
        fetchGroups()
    }

    private func fetchGroups() {
        guard let userId = preference.user?.id else { return }

        let queue = DispatchGroup()
        var totalExpense = 0.0
        var combinedData: [GroupInformation] = []

        currentViewState = .loading
        groupRepository.fetchGroups(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] groups in
                guard let self else { return }

                for group in groups {
                    queue.enter()

                    var members: [AppUser] = []

                    for memberId in group.members {
                        self.fetchUserData(for: memberId) { member in
                            members.append(member)
                        }
                    }

                    self.fetchExpenses(group: group) { expense, owingAmounts in
                        let groupWithExpense = GroupInformation(group: group, oweAmount: expense, memberOweAmount: owingAmounts, members: members)
                        combinedData.append(groupWithExpense)
                        totalExpense += expense
                        queue.leave()
                    }
                }

                queue.notify(queue: .main) {
                    self.currentViewState = .initial
                    self.usersTotalExpense = totalExpense
                    let sortedGroups = combinedData.sorted(by: { ($0.group.createdAt) < ($1.group.createdAt) })
                    self.groupListState = groups.isEmpty ? .noGroup : .hasGroup(groups: sortedGroups)
                }
            }.store(in: &cancelable)
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    private func fetchExpenses(group: Groups, completion: @escaping (Double, [String: Double]) -> Void) {
        expenseRepository.fetchExpensesBy(groupId: group.id ?? "")
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self else { return }
                if group.isDebtSimplified {
                    self.calculateExpensesSimply(expenses: expenses, completion: completion)
                } else {
                    self.calculateExpenses(expenses: expenses, completion: completion)
                }
            }.store(in: &cancelable)
    }

    private func calculateExpenses(expenses: [Expense], completion: @escaping (Double, [String: Double]) -> Void) {
        guard let userId = self.preference.user?.id else { return }

        var expenseByUser = 0.0
        var owesToUser: [String: Double] = [:]
        var owedByUser: [String: Double] = [:]
        var ownAmount: [String: Double] = [:]

        for expense in expenses {
            let splitAmount = expense.amount / Double(expense.splitTo.count)
            if expense.paidBy == userId {
                expenseByUser += expense.splitTo.contains(userId) ? expense.amount - splitAmount : expense.amount
                for member in expense.splitTo where member != userId {
                    owesToUser[member, default: 0.0] += splitAmount
                }
            } else if expense.splitTo.contains(where: { $0 == userId }) {
                expenseByUser -= splitAmount
                owedByUser[expense.paidBy, default: 0.0] += splitAmount
            }
        }

        owesToUser.forEach { userId, owesAmount in
            ownAmount[userId] = owesAmount
        }
        owedByUser.forEach { userId, owedAmount in
            ownAmount[userId] = (ownAmount[userId] ?? 0) - owedAmount
        }
        completion(expenseByUser, ownAmount)
    }

    private func calculateExpensesSimply(expenses: [Expense], completion: @escaping (Double, [String: Double]) -> Void) {
        guard let userId = self.preference.user?.id else { return }

        var expenseByUser = 0.0
        var ownAmount: [String: Double] = [:]

        for expense in expenses {
            ownAmount[expense.paidBy, default: 0.0] += expense.amount
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            for member in expense.splitTo {
                ownAmount[member, default: 0.0] -= splitAmount
            }
        }

        var oweByUser: [String: Double] = [:]
        let debts = self.settleDebts(users: ownAmount)

        for debt in debts where debt.0 == userId || debt.1 == userId {
            expenseByUser += debt.1 == userId ? debt.2 : -debt.2
            oweByUser[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
        }

        completion(expenseByUser, oweByUser)
    }

    private func settleDebts(users: [String: Double]) -> [(String, String, Double)] {
        var creditors: [(String, Double)] = []
        var debtors: [(String, Double)] = []

        // Separate users into creditors and debtors
        for (user, balance) in users {
            if balance > 0 {
                creditors.append((user, balance))
            } else if balance < 0 {
                debtors.append((user, -balance)) // Store as positive for ease of calculation
            }
        }

        // Sort creditors and debtors by the amount they owe or are owed
        creditors.sort { $0.1 < $1.1 }
        debtors.sort { $0.1 < $1.1 }

        var transactions: [(String, String, Double)] = [] // (debtor, creditor, amount)
        var cIdx = 0
        var dIdx = 0

        while cIdx < creditors.count && dIdx < debtors.count { // Process all debts
            let (creditor, credAmt) = creditors[cIdx]
            let (debtor, debtAmt) = debtors[dIdx]
            let minAmt = min(credAmt, debtAmt)

            transactions.append((debtor, creditor, minAmt)) // Record the transaction

            // Update the amounts
            creditors[cIdx] = (creditor, credAmt - minAmt)
            debtors[dIdx] = (debtor, debtAmt - minAmt)

            // Move the index forward if someone's balance is settled
            if creditors[cIdx].1 == 0 { cIdx += 1 }
            if debtors[dIdx].1 == 0 { dIdx += 1 }
        }
        return transactions
    }

    func getMemberData(from members: [AppUser], of id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    func handleCreateGroupBtnTap() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleJoinGroupBtnTap() {
        router.push(.JoinMemberView)
    }

    func handleGroupItemTap(_ group: Groups) {
        if let id = group.id {
            router.push(.GroupHomeView(groupId: id))
        }
    }
}

// MARK: - To show group and expense together
struct GroupInformation: Hashable, Equatable {
    let group: Groups
    let oweAmount: Double
    let memberOweAmount: [String: Double]
    let members: [AppUser]
}

// MARK: - Group States
extension GroupListViewModel {

    enum ViewState {
        case initial
        case loading
    }

    enum GroupListState: Equatable {
        static func == (lhs: GroupListViewModel.GroupListState, rhs: GroupListViewModel.GroupListState) -> Bool {
            lhs.key == rhs.key
        }

        case noGroup
        case hasGroup(groups: [GroupInformation])

        var key: String {
            switch self {
            case .noGroup:
                "noGroup"
            case .hasGroup:
                "hasGroup"
            }
        }
    }
}
