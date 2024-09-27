//
//  AddExpenseViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import Data
import Combine
import BaseStyle
import FirebaseFirestore

class AddExpenseViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var expenseName = ""
    @Published private(set) var payerName = "You"

    @Published var expenseAmount: Double = 0
    @Published var expenseDate = Date()

    @Published var showGroupSelection = false
    @Published var showPayerSelection = false
    @Published var showSplitTypeSelection = false

    @Published var selectedGroup: Groups?
    @Published private(set) var expense: Expense?
    @Published private(set) var splitData: [String: Double] = [:]

    @Published private(set) var groupMembers: [String] = []
    @Published private(set) var selectedMembers: [String] = []
    @Published private(set) var memberProfileUrls: [String] = []

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var splitType: SplitType = .equally

    @Published private(set) var selectedPayers: [String: Double] = [:] {
        didSet {
            updatePayerName()
        }
    }

    var expenseId: String?
    private var groupId: String?
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String? = nil, expenseId: String? = nil) {
        self.router = router
        self.groupId = groupId
        self.expenseId = expenseId
        self.groupId = groupId

        super.init()

        Task {
            if let expenseId {
                await fetchExpenseDetailsWithMembers(expenseId: expenseId)
            } else if let groupId {
                await fetchGroup(groupId: groupId)
                await fetchDefaultUser()
            }
        }
    }

    // MARK: - Data Loading
    private func fetchGroup(groupId: String) async {
        do {
            viewState = .loading
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            if let group {
                selectedGroup = group
                groupMembers = group.members
                selectedMembers = group.members
            }
            await fetchMemberProfileUrls()
            viewState = .initial
        } catch {
            viewState = .initial
            showToastForError()
        }
    }

    private func fetchDefaultUser() async {
        guard let id = preference.user?.id else { return }
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: id)
            guard let user else {
                viewState = .initial
                return
            }
            selectedPayers = [user.id: expenseAmount]
            viewState = .initial
        } catch {
            viewState = .initial
            showToastForError()
        }
    }

    private func fetchExpenseDetailsWithMembers(expenseId: String) async {
        guard let groupId else { return }
        do {
            viewState = .loading
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            await updateViewModelFieldsWithExpense(expense: expense)
            await fetchMemberProfileUrls()
            await fetchAndUpdateGroupData(groupId: groupId)
            viewState = .initial
        } catch {
            viewState = .initial
            showToastForError()
        }
    }

    private func updateViewModelFieldsWithExpense(expense: Expense) async {
        self.expense = expense
        expenseName = expense.name
        expenseAmount = expense.amount
        expenseDate = expense.date.dateValue()
        splitType = expense.splitType
        selectedPayers = expense.paidBy

        if let splitData = expense.splitData {
            self.splitData = splitData
        }
        selectedMembers = expense.splitTo
    }

    private func fetchAndUpdateGroupData(groupId: String) async {
        if let group = await fetchGroupData(for: groupId) {
            self.selectedGroup = group
            self.groupMembers = group.members
        }
    }

    private func fetchGroupData(for groupId: String) async -> Groups? {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            return group
        } catch {
            viewState = .initial
            showToastForError()
            return nil
        }
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let user = try await groupRepository.fetchMemberBy(userId: userId)
            return user
        } catch {
            viewState = .initial
            showToastForError()
            return nil
        }
    }

    private func fetchMemberProfileUrls() async {
        var profileUrls: [String] = []

        for member in selectedMembers {
            if let user = await fetchUserData(for: member) {
                profileUrls.append(user.imageUrl != nil ? user.imageUrl! : "")
            }
        }
        self.memberProfileUrls = profileUrls
    }
}

// MARK: - User Actions
extension AddExpenseViewModel {

    private func updatePayerName() {
        Task {
            if selectedPayers.count == 1 {
                if let user = preference.user, selectedPayers.keys.first == user.id {
                    payerName = "You"
                } else if let payerId = selectedPayers.keys.first,
                          let user = await fetchUserData(for: payerId) {
                    payerName = user.nameWithLastInitial
                }
            } else {
                let payerIds = Array(selectedPayers.keys.prefix(2))
                let user1 = await fetchUserData(for: payerIds[0])
                let user2 = await fetchUserData(for: payerIds[1])

                if let user1, let user2 {
                    if selectedPayers.count == 2 {
                        payerName = "\(user1.nameWithLastInitial) and \(user2.nameWithLastInitial)"
                    } else {
                        let remainingCount = selectedPayers.count - 2
                        payerName = "\(user1.nameWithLastInitial), \(user2.nameWithLastInitial) and +\(remainingCount)"
                    }
                }
            }
        }
    }

    func handleGroupBtnAction() {
        showGroupSelection = expenseId == nil
    }

    func handleGroupSelectionAction(group: Groups) {
        Task {
            await handleGroupSelection(group: group)
        }
    }

    private func handleGroupSelection(group: Groups) async {
        selectedGroup = group
        groupMembers = group.members
        selectedMembers = group.members
        await fetchMemberProfileUrls()
    }

    func handlePayerBtnAction() {
        guard selectedGroup != nil else {
            self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "Please select group to get payer list."))
            return
        }
        if let user = preference.user, selectedPayers == [:] || selectedPayers[user.id] == 0 {
            selectedPayers = [user.id: expenseAmount]
        }
        showPayerSelection = true
    }

    func handlePayerSelection(payers: [String: Double]) {
        selectedPayers = payers
    }

    func handleSplitTypeBtnAction() {
        guard selectedGroup != nil else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please select group to get payer list."))
            return
        }

        guard expenseAmount > 0 else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please enter a cost for your expense first!"))
            return
        }
        showSplitTypeSelection = true
    }

    func handleSplitTypeSelectionAction(members: [String], splitData: [String: Double], splitType: SplitType) {
        Task {
            await handleSplitTypeSelection(members: members, splitData: splitData, splitType: splitType)
        }
    }

    private func handleSplitTypeSelection(members: [String], splitData: [String: Double], splitType: SplitType) async {
        selectedMembers = splitType == .equally ? members : splitData.map({ $0.key })
        self.splitData = splitData
        self.splitType = splitType
        await fetchMemberProfileUrls()
    }

    func handleSaveAction(completion: @escaping (Bool) -> Void) {
        if let user = preference.user, selectedPayers == [:] || selectedPayers[user.id] == 0 {
            selectedPayers = [user.id: expenseAmount]
        }

        if expenseName == "" || expenseAmount == 0 || selectedGroup == nil || selectedPayers == [:] {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning",
                                            message: "Please fill all data to add expense."))
            return
        }

        let totalPaidAmount = selectedPayers.map { $0.value }.reduce(0, +)
        let totalSharedAmount = splitData.map { $0.value }.reduce(0, +)

        if (splitType == .fixedAmount && totalSharedAmount != expenseAmount) || (selectedPayers.count > 1 && totalPaidAmount != expenseAmount) {
            let differenceAmount = (splitType == .fixedAmount && totalSharedAmount != expenseAmount) ? totalSharedAmount : totalPaidAmount

            showAlertFor(title: "Error",
                         message: "The total of everyone's paid shares (\(differenceAmount.formattedCurrency)) is different than the total cost (\(expenseAmount.formattedCurrency))")
            return
        }

        guard let selectedGroup, let groupId = selectedGroup.id, let user = preference.user else { return }

        Task {
            if let expense {
                await handleUpdateExpenseAction(groupId: groupId, expense: expense, completion: completion)
            } else {
                await handleAddExpenseAction(groupId: groupId, userId: user.id, completion: completion)
            }
        }
    }

    private func handleAddExpenseAction(groupId: String, userId: String, completion: (Bool) -> Void) async {
        let expense = Expense(name: expenseName.trimming(spaces: .leadingAndTrailing), amount: expenseAmount,
                              date: Timestamp(date: expenseDate), paidBy: selectedPayers, addedBy: userId,
                              splitTo: (splitType == .equally) ? selectedMembers : splitData.map({ $0.key }),
                              splitType: splitType, splitData: splitData)

        await addExpense(groupId: groupId, expense: expense, completion: completion)
    }

    private func handleUpdateExpenseAction(groupId: String, expense: Expense, completion: (Bool) -> Void) async {
        var newExpense = expense
        newExpense.name = expenseName.trimming(spaces: .leadingAndTrailing)
        newExpense.amount = expenseAmount
        newExpense.date = Timestamp(date: expenseDate)

        if selectedPayers.count == 1 {
            newExpense.paidBy = [selectedPayers.first?.key ?? "": expenseAmount]
        } else {
            newExpense.paidBy = selectedPayers
        }

        newExpense.splitType = splitType
        newExpense.splitTo = (splitType == .equally) ? selectedMembers : splitData.map({ $0.key })
        newExpense.splitData = splitData

        await updateExpense(groupId: groupId, expense: newExpense, oldExpense: expense, completion: completion)
    }

    private func addExpense(groupId: String, expense: Expense, completion: (Bool) -> Void) async {
        do {
            viewState = .loading
            let newExpense = try await expenseRepository.addExpense(groupId: groupId, expense: expense)
            let expenseInfo: [String: Any] = ["groupId": groupId, "expense": newExpense]
            NotificationCenter.default.post(name: .addExpense, object: nil, userInfo: expenseInfo)

            if !(selectedGroup?.hasExpenses ?? false) { selectedGroup?.hasExpenses = true }

            await updateGroupMemberBalance(expense: expense, updateType: .Add)
            viewState = .initial
            completion(true)
        } catch {
            viewState = .initial
            completion(false)
            showToastForError()
        }
    }

    private func updateExpense(groupId: String, expense: Expense, oldExpense: Expense, completion: (Bool) -> Void) async {
        do {
            viewState = .loading
            try await expenseRepository.updateExpense(groupId: groupId, expense: expense)
            NotificationCenter.default.post(name: .updateExpense, object: expense)
            await updateGroupMemberBalance(expense: expense, updateType: .Update(oldExpense: oldExpense))
            viewState = .initial
            completion(true)
        } catch {
            viewState = .initial
            completion(false)
            showToastForError()
        }
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group = selectedGroup else { return }
        do {
            let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group)
        } catch {
            viewState = .initial
            showToastForError()
        }
    }
}

extension AddExpenseViewModel {
    enum ViewState {
        case initial
        case loading
    }

    enum AddExpenseField {
        case expenseName
        case amount
    }
}
