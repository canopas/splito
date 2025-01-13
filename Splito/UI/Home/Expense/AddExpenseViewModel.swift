//
//  AddExpenseViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import Data
import BaseStyle
import FirebaseFirestore
import AVFoundation
import SwiftUI

class AddExpenseViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var expenseName = ""
    @Published var expenseNote: String = ""
    @Published var expenseImage: UIImage?
    @Published var expenseDate = Date()
    @Published var expenseAmount: Double = 0
    @Published private(set) var payerName = "You"
    @Published private(set) var expenseImageUrl: String?
    @Published private(set) var groupMembers: [String] = []
    @Published private(set) var selectedMembers: [String] = []
    @Published private(set) var splitData: [String: Double] = [:]
    @Published private(set) var selectedPayers: [String: Double] = [:] {
        didSet { updatePayerName() }
    }

    @Published var showImagePicker = false
    @Published var showAddNoteEditor = false
    @Published var showGroupSelection = false
    @Published var showPayerSelection = false
    @Published var showImagePickerOptions = false
    @Published var showSplitTypeSelection = false
    @Published var showCurrencyPicker = false
    @Published private(set) var showLoader = false
    @Published private(set) var sourceTypeIsCamera = false

    @Published var selectedCurrency: Currency
    @Published var selectedGroup: Groups?
    @Published private(set) var expense: Expense?
    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var splitType: SplitType = .equally

    let expenseId: String?
    private let groupId: String?
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String? = nil, expenseId: String? = nil) {
        self.router = router
        self.groupId = groupId
        self.expenseId = expenseId
        self.selectedCurrency = Currency.getCurrentLocalCurrency()
        super.init()
        loadInitialData()
    }

    private func loadInitialData() {
        Task { [weak self] in
            if let expenseId = self?.expenseId {
                await self?.fetchExpenseDetailsWithMembers(expenseId: expenseId)
            } else if let groupId = self?.groupId {
                await self?.fetchGroupData(groupId: groupId)
            }
        }
    }

    // MARK: - Data Loading
    private func fetchGroupData(groupId: String) async {
        guard let userId = preference.user?.id else { return }
        viewState = .loading
        await fetchAndUpdateGroupData(groupId: groupId)
        selectedPayers = [userId: expenseAmount]
        viewState = .initial
        LogD("AddExpenseViewModel: \(#function) Group fetched successfully.")
    }

    private func fetchExpenseDetailsWithMembers(expenseId: String) async {
        guard let groupId else { return }
        do {
            viewState = .loading
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            await updateViewModelFieldsWithExpense(expense: expense)
            await fetchAndUpdateGroupData(groupId: groupId)
            viewState = .initial
            LogD("AddExpenseViewModel: \(#function) Expense details with members fetched successfully.")
        } catch {
            handleError(error, context: "fetch expense details with members")
        }
    }

    private func fetchAndUpdateGroupData(groupId: String) async {
        do {
            if let group = try await groupRepository.fetchGroupBy(id: groupId) {
                selectedGroup = group
                groupMembers = group.members
                selectedMembers = group.members
                selectedCurrency = Currency.getCurrencyOfCode(group.defaultCurrency ?? "INR")
            }
            LogD("AddExpenseViewModel: \(#function) Group fetched successfully.")
        } catch {
            handleError(error, context: "fetch group")
        }
    }

    private func updateViewModelFieldsWithExpense(expense: Expense) async {
        self.expense = expense
        expenseName = expense.name
        expenseAmount = expense.amount
        expenseDate = expense.date.dateValue()
        splitType = expense.splitType
        selectedPayers = expense.paidBy
        expenseImageUrl = expense.imageUrl
        expenseNote = expense.note ?? ""
        if let splitData = expense.splitData {
            self.splitData = splitData
        }
        selectedMembers = expense.splitTo
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let user = try await groupRepository.fetchMemberBy(memberId: userId)
            LogD("AddExpenseViewModel: \(#function) Member fetched successfully.")
            return user
        } catch {
            handleError(error, context: "fetch member")
            return nil
        }
    }
}

// MARK: - Handle Payers data to view
extension AddExpenseViewModel {
    private func updatePayerName() {
        Task { [weak self] in
            guard let self else { return }
            if self.selectedPayers.count == 1 {
                if let user = preference.user, self.selectedPayers.keys.first == user.id {
                    self.payerName = "You"
                } else if let payerId = self.selectedPayers.keys.first, let user = await self.fetchUserData(for: payerId) {
                    self.payerName = user.nameWithLastInitial
                }
            } else {
                let payerIds = Array(self.selectedPayers.keys.prefix(2))
                let user1 = await self.fetchUserData(for: payerIds[0])
                let user2 = await self.fetchUserData(for: payerIds[1])
                if let user1, let user2, let currentUser = preference.user {
                    let user1Name = user1.id == currentUser.id ? "You" : user1.nameWithLastInitial
                    let user2Name = user2.id == currentUser.id ? "You" : user2.nameWithLastInitial
                    if self.selectedPayers.count == 2 {
                        self.payerName = "\(user1Name) and \(user2Name)"
                    } else {
                        let remainingPayersCount = self.selectedPayers.count - 2
                        self.payerName = "\(user1Name), \(user2Name) and +\(remainingPayersCount)"
                    }
                }
            }
        }
    }

    private func updateSelectedPayers() {
        // Check if no payers are selected or current user's paid amount is 0 then set current user as payer with expense amount
        if let userId = preference.user?.id, selectedPayers == [:] || (selectedPayers[userId]) == 0 {
            selectedPayers = [userId: expenseAmount]
        }

        // If there is only one payer, update their amount to match the expense amount
        if selectedPayers.count == 1, let firstPayer = selectedPayers.keys.first {
            selectedPayers[firstPayer] = expenseAmount
        }
    }
}

// MARK: - User Actions
extension AddExpenseViewModel {
    private func handleError(_ error: Error, context: String) {
        viewState = .initial
        LogE("AddExpenseViewModel: Failed to \(context) with error: \(error)")
        showToastForError()
    }

    func handleGroupBtnAction() {
        showGroupSelection = expenseId == nil
    }

    func handleExpenseImageTap() {
        UIApplication.shared.endEditing()
        showImagePickerOptions = true
    }

    func handleNoteBtnTap() {
        showAddNoteEditor = true
    }

    func handleNoteSaveBtnTap(note: String) {
        showAddNoteEditor = false
        expenseNote = note
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .camera:
            self.checkCameraPermission { [weak self] in
                self?.sourceTypeIsCamera = true
                self?.showImagePicker = true
            }
        case .gallery:
            sourceTypeIsCamera = false
            showImagePicker = true
        case .remove:
            withAnimation { [weak self] in
                self?.expenseImage = nil
                self?.expenseImageUrl = nil
            }
        case .removeAll: break
        }
    }

    private func checkCameraPermission(authorized: @escaping (() -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { authorized() }
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!",
                                      message: "Camera access is required to take picture for expenses",
                                      positiveBtnTitle: "Allow", positiveBtnAction: { [weak self] in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                self?.showAlert = false
            }))
        case .authorized:
            authorized()
        default:
            return
        }
    }

    func handleGroupSelectionAction(group: Groups) {
        Task { [weak self] in
            await self?.handleGroupSelection(group: group)
        }
    }

    private func handleGroupSelection(group: Groups) async {
        selectedGroup = group
        groupMembers = group.members
        selectedMembers = group.members
    }

    func handlePayerBtnAction() {
        guard selectedGroup != nil else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "Please select a group to get payer list."))
            return
        }
        updateSelectedPayers()
        showPayerSelection = true
    }

    func handlePayerSelection(payers: [String: Double]) {
        selectedPayers = payers
    }

    func handleSplitTypeBtnAction() {
        guard selectedGroup != nil else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please select a group before choosing the split option."))
            return
        }
        guard expenseAmount > 0 else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please enter a cost for your expense first!"))
            return
        }
        showSplitTypeSelection = true
    }

    func handleSplitTypeSelectionAction(splitData: [String: Double], splitType: SplitType) {
        Task {
            await handleSplitTypeSelection(splitData: splitData, splitType: splitType)
        }
    }

    private func handleSplitTypeSelection(splitData: [String: Double], splitType: SplitType) async {
        selectedMembers = splitData.map({ $0.key })
        self.splitData = splitData
        self.splitType = splitType
    }

    func showSaveFailedError() {
        guard let selectedGroup, let expense else { return }
        guard validateMembersInGroup(group: selectedGroup, expense: expense) else {
            showAlertFor(message: "This expense involves a person who has left the group, and thus it can no longer be edited. If you wish to change this expense, you must first add that person back to your group.")
            return
        }
        self.showToastFor(toast: ToastPrompt(type: .error, title: "Whoops!", message: "Failed to save expense."))
    }

    private func validateMembersInGroup(group: Groups, expense: Expense) -> Bool {
        for payer in expense.paidBy where !group.members.contains(payer.key) { return false }
        for memberId in expense.splitTo where !group.members.contains(memberId) { return false }
        return true
    }
}

// MARK: - Handle Expense Save Action
extension AddExpenseViewModel {
    func handleSaveAction() async -> Bool {
        self.updateSelectedPayers()
        guard validateInputs() else { return false }
        guard validateSplitAndPaidAmounts() else { return false }
        guard let selectedGroup, let userId = preference.user?.id else { return false }
        if let expense {
            return await handleUpdateExpenseAction(userId: userId, group: selectedGroup, expense: expense)
        } else {
            return await handleAddExpenseAction(userId: userId, group: selectedGroup)
        }
    }

    private func validateInputs() -> Bool {
        if expenseName.isEmpty || expenseAmount == 0 || selectedGroup == nil || selectedPayers.isEmpty {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning", message: "Please fill all data to add expense."))
            return false
        }
        return true
    }

    private func validateSplitAndPaidAmounts() -> Bool {
        var totalSharedAmount = splitData.mapValues { $0.rounded(to: 2) }.values.reduce(0, +)
        let totalPaidAmount = selectedPayers.map { $0.value }.reduce(0, +)

        if splitType == .equally && totalSharedAmount != expenseAmount {
            selectedMembers.forEach { memberId in
                splitData[memberId] = calculateEqualSplitAmount(memberId: memberId, amount: expenseAmount, splitTo: selectedMembers)
                totalSharedAmount = splitData.map { $0.value }.reduce(0, +)
            }
        }

        if (splitType == .fixedAmount || splitType == .equally) && totalSharedAmount != expenseAmount {
            let amountDescription = totalSharedAmount < expenseAmount ? "short" : "over"
            let differenceAmount = totalSharedAmount < expenseAmount ? (expenseAmount - totalSharedAmount) : (totalSharedAmount - expenseAmount)
            showAlertFor(title: "Error!",
                         message: "The amounts do not add up to the total cost of \(expenseAmount.formattedCurrency). You are \(amountDescription) by \(differenceAmount.formattedCurrency).")
            return false
        } else if selectedPayers.count > 1 && totalPaidAmount != expenseAmount {
            showAlertFor(title: "Error",
                         message: "The total of everyone's paid shares (\(totalPaidAmount.formattedCurrency)) is different than the total cost (\(expenseAmount.formattedCurrency))")
            return false
        } else if selectedPayers.count == 1 && selectedPayers.values.reduce(0, +) != expenseAmount {
            showAlertFor(title: "Error",
                         message: "The total amount paid by the selected payer does not match the expense amount. Please adjust the payment distribution.")
            return false
        }
        return true
    }

    private func handleAddExpenseAction(userId: String, group: Groups) async -> Bool {
        guard let groupId else { return false }
        let splitTo = splitData.map { $0.key }
        let participants = Array(Set(splitTo + selectedPayers.keys))
        let expense = Expense(groupId: groupId, name: expenseName.trimming(spaces: .leadingAndTrailing), amount: expenseAmount,
                              date: Timestamp(date: expenseDate), addedBy: userId, note: expenseNote, splitType: splitType,
                              splitTo: splitTo, splitData: splitData, paidBy: selectedPayers, participants: participants)
        return await addExpense(group: group, expense: expense)
    }

    private func addExpense(group: Groups, expense: Expense) async -> Bool {
        guard let groupId = group.id else { return false }
        do {
            showLoader = true
            let newExpense = try await expenseRepository.addExpense(group: group, expense: expense, imageData: getImageData())
            let expenseInfo: [String: Any] = ["groupId": groupId, "expense": newExpense]
            NotificationCenter.default.post(name: .addExpense, object: nil, userInfo: expenseInfo)

            if !group.hasExpenses { selectedGroup?.hasExpenses = true }
            await updateGroupMemberBalance(expense: newExpense, updateType: .Add)

            showLoader = false
            LogD("AddExpenseViewModel: \(#function) Expense added successfully.")
            return true
        } catch {
            showLoader = false
            LogE("AddExpenseViewModel: \(#function) Failed to add expense: \(error).")
            showToastForError()
            return false
        }
    }

    private func handleUpdateExpenseAction(userId: String, group: Groups, expense: Expense) async -> Bool {
        guard let groupId = group.id else { return false }

        var newExpense = expense
        newExpense.groupId = groupId
        newExpense.name = expenseName.trimming(spaces: .leadingAndTrailing)
        newExpense.amount = expenseAmount
        newExpense.date = Timestamp(date: expenseDate)
        newExpense.updatedAt = Timestamp()
        newExpense.updatedBy = userId
        newExpense.note = expenseNote

        if selectedPayers.count == 1, let payerId = selectedPayers.keys.first {
            newExpense.paidBy = [payerId: expenseAmount]
        } else {
            newExpense.paidBy = selectedPayers
        }

        newExpense.splitTo = splitData.map { $0.key }
        newExpense.splitData = splitData
        newExpense.splitType = splitType

        let participants = Array(Set(newExpense.splitTo + newExpense.paidBy.keys))
        newExpense.participants = participants

        return await updateExpense(group: group, expense: newExpense, oldExpense: expense)
    }

    private func updateExpense(group: Groups, expense: Expense, oldExpense: Expense) async -> Bool {
        guard validateMembersInGroup(group: group, expense: expense), let expenseId else { return false }

        do {
            showLoader = true
            let updatedExpense = try await expenseRepository.updateExpenseWithImage(imageData: getImageData(),
                                                                                    newImageUrl: expenseImageUrl,
                                                                                    group: group, expense: (expense, oldExpense),
                                                                                    type: .expenseUpdated)
            NotificationCenter.default.post(name: .updateExpense, object: updatedExpense)

            guard hasExpenseChanged(updatedExpense, oldExpense: oldExpense) else { return true }
            await updateGroupMemberBalance(expense: updatedExpense, updateType: .Update(oldExpense: oldExpense))

            showLoader = false
            LogD("AddExpenseViewModel: \(#function) Expense updated successfully.")
            return true
        } catch {
            showLoader = false
            LogE("AddExpenseViewModel: \(#function) Failed to update expense \(expenseId): \(error).")
            showToastForError()
            return false
        }
    }

    private func getImageData() -> Data? {
        let resizedImage = expenseImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)
        return imageData
    }

    private func hasExpenseChanged(_ expense: Expense, oldExpense: Expense) -> Bool {
        return oldExpense.amount != expense.amount || oldExpense.paidBy != expense.paidBy ||
        oldExpense.splitTo != expense.splitTo || oldExpense.splitType != expense.splitType ||
        oldExpense.splitData != expense.splitData || oldExpense.isActive != expense.isActive ||
        oldExpense.date != expense.date
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group = selectedGroup, let userId = preference.user?.id, let expenseId = expense.id else {
            LogE("AddExpenseViewModel: \(#function) Group or expense information not found.")
            showLoader = false
            return
        }
        do {
            let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
            group.balances = memberBalance
            group.updatedAt = Timestamp()
            group.updatedBy = userId
            try await groupRepository.updateGroup(group: group, type: .none)
            NotificationCenter.default.post(name: .updateGroup, object: group)
            LogD("AddExpenseViewModel: \(#function) Member balances updated successfully.")
        } catch {
            showLoader = false
            LogE("AddExpenseViewModel: \(#function) Failed to update member balance for expense \(expenseId): \(error).")
            showToastForError()
        }
    }
}

extension AddExpenseViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
