//
//  GroupSettingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import Combine
import BaseStyle

class GroupSettingViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    private let groupId: String
    private let router: Router<AppRoute>
    private var memberRemoveType: MemberRemoveType = .leave

    @Published var isAdmin = false
    @Published var showLeaveGroupDialog = false
    @Published var showRemoveMemberDialog = false

    @Published var groupTotalExpense = 0.0
    @Published var amountOweByMember: [String: Double] = [:]

    @Published var group: Groups?
    @Published var members: [AppUser] = []
    @Published var currentViewState: ViewState = .loading

    @Published var isDebtSimplified = false {
        didSet {
            updateGroupForSimplifyDebt()
        }
    }

    private var transactions: [Transactions] = []

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
    }

    // MARK: - Data Loading
    func fetchGroupDetails() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.checkForGroupAdmin()
                self.isDebtSimplified = group.isDebtSimplified
                self.fetchGroupMembers()
            }.store(in: &cancelable)
    }

    private func fetchGroupMembers() {
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] members in
                guard let self else { return }
                self.sortGroupMembers(members: members)
                self.fetchTransactions()
                self.fetchExpenses()
            }.store(in: &cancelable)
    }

    func sortGroupMembers(members: [AppUser]) {
        guard let userId = preference.user?.id else { return }

        var sortedMembers = members
        sortedMembers.sort { (member1: AppUser, member2: AppUser) in
            if member1.id == userId {
                return true
            } else if member2.id == userId {
                return false
            } else {
                return member1.fullName < member2.fullName
            }
        }
        self.members = sortedMembers
    }

    func getMemberName(id: String, needFullName: Bool = false) -> String {
        guard let member = members.first(where: { $0.id == id }) else { return "" }
        return needFullName ? member.fullName : member.nameWithLastInitial
    }

    private func fetchTransactions() {
        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleServiceError(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self else { return }
            self.transactions = transactions
            print("xxx \(transactions)")
        }.store(in: &cancelable)
    }

    private func fetchExpenses() {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self else { return }
                self.calculateExpenses(expenses: expenses)
            }.store(in: &cancelable)
    }

    private func calculateExpenses(expenses: [Expense]) {
        for expense in expenses {
            self.amountOweByMember[expense.paidBy, default: 0.0] += expense.amount

            let splitAmount = expense.amount / Double(expense.splitTo.count)
            for member in expense.splitTo {
                self.amountOweByMember[member, default: 0.0] -= splitAmount
            }
        }

        for transaction in transactions {
            self.amountOweByMember[transaction.payerId, default: 0.0] += transaction.amount
            self.amountOweByMember[transaction.receiverId, default: 0.0] -= transaction.amount
        }

        DispatchQueue.main.async {
            self.currentViewState = .initial
        }
    }

    private func checkForGroupAdmin() {
        guard let userId = preference.user?.id, let group else { return }
        isAdmin = userId == group.createdBy
    }

    private func updateGroupForSimplifyDebt() {
        guard var group, group.isDebtSimplified != isDebtSimplified else { return }

        currentViewState = .loading
        group.isDebtSimplified = isDebtSimplified

        groupRepository.updateGroup(group: group)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { _ in
                self.currentViewState = .initial
                self.showToastFor(toast: ToastPrompt(type: .success, title: "Success",
                                                     message: "Simplify debts turned \(self.isDebtSimplified ? "on" : "off")"))
            }.store(in: &cancelable)
    }

    // MARK: - User Actions

    func onRemoveAndLeaveFromGroupTap() {
        showAlert = true
    }

    func handleEditGroupTap() {
        router.push(.CreateGroupView(group: group))
    }

    func handleAddMemberTap() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleLeaveGroupTap() {
        guard let userId = preference.user?.id else { return }
        showLeaveGroupAlert(memberId: userId)
        showAlert = true
    }

    func handleMemberTap(member: AppUser) {
        guard let userId = preference.user?.id else { return }
        if userId == member.id {
            showLeaveGroupDialog = true
            showLeaveGroupAlert(memberId: member.id)
        } else {
            showRemoveMemberDialog = true
            showRemoveMemberAlert(memberId: member.id)
        }
    }

    private func showRemoveMemberAlert(memberId: String) {
        guard amountOweByMember[memberId] == 0 else {
            memberRemoveType = .remove
            showDebtOutstandingAlert(memberId: memberId)
            return
        }

        alert = .init(title: "Remove from group?",
                      message: "Are you sure you want to remove this member from the group?",
                      positiveBtnTitle: "Remove",
                      positiveBtnAction: { self.removeMemberFromGroup(memberId: memberId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func showLeaveGroupAlert(memberId: String) {
        guard amountOweByMember[memberId] == 0 || amountOweByMember[memberId] == nil else {
            memberRemoveType = .leave
            showDebtOutstandingAlert(memberId: memberId)
            return
        }

        alert = .init(title: "Leave Group?",
                      message: "Are you absolutely sure you want to leave this group?",
                      positiveBtnTitle: "Leave",
                      positiveBtnAction: { self.removeMemberFromGroup(memberId: memberId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func showDebtOutstandingAlert(memberId: String) {
        let leaveText = "You can't leave this group because you have outstanding debts with other group members. Please make sure all of your debts have been settle up, and try again."

        let memberName = members.first(where: { $0.id == memberId })?.firstName ?? ""
        let removeText = "You can't remove \(memberName) from this group because they have outstanding debts with other group members. Please make sure all of \(memberName)'s debts have been settle up, and try again."

        alert = .init(title: "Whoops!",
                      message: memberRemoveType == .leave ? leaveText : removeText,
                      negativeBtnTitle: "Ok",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func removeMemberFromGroup(memberId: String) {
        guard let group else { return }
        guard let userId = preference.user?.id else { return }

        currentViewState = .loading
        groupRepository.removeMemberFrom(group: group, memberId: memberId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { _ in
                self.currentViewState = .initial
                if userId == memberId {
                    self.goBackToGroupList()
                } else {
                    self.showAlert = false
                    self.showToastFor(toast: ToastPrompt(type: .success, title: "Success", message: "Group member removed"))
                }
            }.store(in: &cancelable)
    }

    func handleDeleteGroupTap() {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to delete this group? This will remove this group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { self.deleteGroupWithMembers() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroupWithMembers() {
        currentViewState = .loading
        groupRepository.deleteGroup(groupID: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { _ in
                self.currentViewState = .initial
                self.goBackToGroupList()
            }.store(in: &cancelable)
    }

    // MARK: - Navigation
    func goBackToGroupList() {
        router.popToRoot()
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        currentViewState = .initial
        showToastFor(error)
    }
}

// MARK: - Group State
extension GroupSettingViewModel {
    enum ViewState {
        case initial
        case loading
        case hasMembers
    }

    enum MemberRemoveType: Equatable {
        case remove
        case leave
    }
}
