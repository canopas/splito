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
            Task {
                await updatePayerName()
            }
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
                await fetchExpenseDetails(expenseId: expenseId)
            } else if let groupId {
                await fetchGroup(groupId: groupId)
                await fetchDefaultUser()
            }
        }
    }

    // MARK: - Data Loading
    private func fetchGroup(groupId: String) async {
        do {
            self.viewState = .loading
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
            handleServiceError(error)
        }
    }

    private func fetchDefaultUser() async {
        guard let id = preference.user?.id else { return }
        viewState = .loading

        do {
            let user = try await userRepository.fetchUserBy(userID: id)
            guard let user else {
                viewState = .initial
                return
            }
            selectedPayers = [user.id: expenseAmount]
            viewState = .initial
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    private func fetchExpenseDetails(expenseId: String) async {
        guard let groupId else { return }

        viewState = .loading

        do {
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            self.expense = expense
            expenseName = expense.name
            expenseAmount = expense.amount
            expenseDate = expense.date.dateValue()
            splitType = expense.splitType

            if let splitData = expense.splitData {
                self.splitData = splitData
            }
            selectedMembers = expense.splitTo
            await fetchMemberProfileUrls()

            if let group = await fetchGroupData(for: groupId) {
                self.selectedGroup = group
                self.groupMembers = group.members
                self.selectedPayers = expense.paidBy
                self.viewState = .initial
            }
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    private func fetchGroupData(for groupId: String) async -> Groups? {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            return group
        } catch {
            viewState = .initial
            handleServiceError(error)
            return nil
        }
    }

    func fetchUserData(for userId: String) async -> AppUser? {
        do {
            return try await groupRepository.fetchMemberBy(userId: userId)
        } catch {
            viewState = .initial
            handleServiceError(error)
            return nil
        }
    }

    func fetchMemberProfileUrls() async {
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

    private func updatePayerName() async {
        let payerCount = selectedPayers.count

        if payerCount == 1 {
            if let user = preference.user, selectedPayers.keys.first == user.id {
                payerName = "You"
            } else {
                if let user = await fetchUserData(for: selectedPayers.keys.first ?? "") {
                    payerName = user.nameWithLastInitial
                }
            }
        } else {
            let payerIds = Array(selectedPayers.keys.prefix(2))
            if let user1 = await fetchUserData(for: payerIds[0]) {
                if let user2 = await fetchUserData(for: payerIds[1]) {
                    if payerCount == 2 {
                        payerName = "\(user1.nameWithLastInitial) and \(user2.nameWithLastInitial)"
                    } else {
                        let remainingCount = payerCount - 2
                        payerName = "\(user1.nameWithLastInitial), \(user2.nameWithLastInitial) and +\(remainingCount)"
                    }
                }
            }
        }
    }

    func handleGroupBtnAction() {
        showGroupSelection = expenseId == nil
    }

    func handleGroupSelection(group: Groups) async {
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

    func handleSplitTypeSelection(members: [String], splitData: [String: Double], splitType: SplitType) async {
        selectedMembers = splitType == .equally ? members : splitData.map({ $0.key })
        self.splitData = splitData
        self.splitType = splitType
        await fetchMemberProfileUrls()
    }

    func handleSaveAction() async {
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

        if let expense {
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

            await updateExpense(groupId: groupId, expense: newExpense, oldExpense: expense)
        } else {
            let expense = Expense(name: expenseName.trimming(spaces: .leadingAndTrailing), amount: expenseAmount,
                                  date: Timestamp(date: expenseDate), paidBy: selectedPayers, addedBy: user.id,
                                  splitTo: (splitType == .equally) ? selectedMembers : splitData.map({ $0.key }),
                                  splitType: splitType, splitData: splitData)

            await addExpense(groupId: groupId, expense: expense)
        }
    }

    private func addExpense(groupId: String, expense: Expense) async {
        viewState = .loading

        do {
            viewState = .loading
            let newExpense = try await expenseRepository.addExpense(groupId: groupId, expense: expense)
            viewState = .initial
            NotificationCenter.default.post(name: .addExpense, object: newExpense)
            if !(selectedGroup?.hasExpenses ?? false) {
                selectedGroup?.hasExpenses = true
            }
            await updateGroupMemberBalance(expense: expense, updateType: .Add)
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    private func updateExpense(groupId: String, expense: Expense, oldExpense: Expense) async {
        viewState = .loading

        do {
            viewState = .loading
            try await expenseRepository.updateExpense(groupId: groupId, expense: expense)
            viewState = .initial
            NotificationCenter.default.post(name: .updateExpense, object: expense)
            await updateGroupMemberBalance(expense: expense, updateType: .Update(oldExpense: oldExpense))
        } catch {
            viewState = .initial
            handleServiceError(error)
        }
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group = selectedGroup else { return }

        let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
        group.balances = memberBalance

        do {
            try await groupRepository.updateGroup(group: group)
            viewState = .initial
        } catch {
            viewState = .initial
            handleServiceError(error)
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
