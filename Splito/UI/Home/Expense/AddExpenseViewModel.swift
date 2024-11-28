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
    @Published private(set) var expenseImageUrl: String?
    @Published private(set) var payerName = "You"

    @Published var expenseImage: UIImage?
    @Published var expenseDate = Date()
    @Published var expenseAmount: Double = 0

    @Published var showImagePicker = false
    @Published var showAddNoteEditor = false
    @Published var showGroupSelection = false
    @Published var showPayerSelection = false
    @Published var showImagePickerOptions = false
    @Published var showSplitTypeSelection = false
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var sourceTypeIsCamera = false

    @Published var selectedGroup: Groups?
    @Published private(set) var expense: Expense?
    @Published private(set) var splitData: [String: Double] = [:]

    @Published private(set) var groupMembers: [String] = []
    @Published private(set) var selectedMembers: [String] = []

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var splitType: SplitType = .equally

    @Published private(set) var selectedPayers: [String: Double] = [:] {
        didSet {
            updatePayerName()
        }
    }

    let expenseId: String?
    private let groupId: String?
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String? = nil, expenseId: String? = nil) {
        self.router = router
        self.groupId = groupId
        self.expenseId = expenseId
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
            viewState = .initial
            LogD("AddExpenseViewModel: \(#function) Group fetched successfully.")
        } catch {
            viewState = .initial
            LogE("AddExpenseViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
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
            LogD("AddExpenseViewModel: \(#function) Default user fetched successfully.")
        } catch {
            viewState = .initial
            LogE("AddExpenseViewModel: \(#function) Failed to fetch default user: \(error).")
            showToastForError()
        }
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
            viewState = .initial
            LogE("AddExpenseViewModel: \(#function) Failed to fetch expense details with members: \(error).")
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
        expenseImageUrl = expense.imageUrl
        expenseNote = expense.note ?? ""

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
            LogD("AddExpenseViewModel: \(#function) Group fetched successfully.")
            return group
        } catch {
            viewState = .initial
            LogE("AddExpenseViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            showToastForError()
            return nil
        }
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let user = try await groupRepository.fetchMemberBy(userId: userId)
            LogD("AddExpenseViewModel: \(#function) Member fetched successfully.")
            return user
        } catch {
            viewState = .initial
            LogE("AddExpenseViewModel: \(#function) Failed to fetch member \(userId): \(error).")
            showToastForError()
            return nil
        }
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

    func handleExpenseImageTap() {
        UIApplication.shared.endEditing()
        showImagePickerOptions = true
    }

    func handleNoteBtnTap() {
        showAddNoteEditor = true
    }

    func handleNoteSaveBtnTap(note: String) {
        showAddNoteEditor = false
        self.expenseNote = note
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .camera:
            self.checkCameraPermission {
                self.sourceTypeIsCamera = true
                self.showImagePicker = true
            }
        case .gallery:
            sourceTypeIsCamera = false
            showImagePicker = true
        case .remove:
            withAnimation {
                expenseImage = nil
                expenseImageUrl = nil
            }
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
            showAlertFor(alert: .init(title: "Important!", message: "Camera access is required to take picture for expenses",
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
        Task {
            await handleGroupSelection(group: group)
        }
    }

    private func handleGroupSelection(group: Groups) async {
        selectedGroup = group
        groupMembers = group.members
        selectedMembers = group.members
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
    }

    func showSaveFailedError() {
        guard let selectedGroup, let expense else { return }
        guard validateMembersInGroup(group: selectedGroup, expense: expense) else {
            showAlertFor(message: "This expense involves a person who has left the group, and thus it can no longer be edited. If you wish to change this expense, you must first add that person back to your group.")
            return
        }
        self.showToastFor(toast: ToastPrompt(type: .error, title: "Oops", message: "Failed to save expense."))
    }

    private func validateMembersInGroup(group: Groups, expense: Expense) -> Bool {
        for payer in expense.paidBy where !group.members.contains(payer.key) {
            return false
        }
        for memberId in expense.splitTo where !group.members.contains(memberId) {
            return false
        }

        return true
    }

    func handleSaveAction() async -> Bool {
        if let user = preference.user, selectedPayers == [:] || selectedPayers[user.id] == 0 {
            selectedPayers = [user.id: expenseAmount]
        }

        if expenseName == "" || expenseAmount == 0 || selectedGroup == nil || selectedPayers == [:] {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning",
                                            message: "Please fill all data to add expense."))
            return false
        }

        let totalPaidAmount = selectedPayers.map { $0.value }.reduce(0, +)
        let totalSharedAmount = splitData.map { $0.value }.reduce(0, +)

        if (splitType == .fixedAmount && totalSharedAmount != expenseAmount) || (selectedPayers.count > 1 && totalPaidAmount != expenseAmount) {
            let differenceAmount = (splitType == .fixedAmount && totalSharedAmount != expenseAmount) ? totalSharedAmount : totalPaidAmount

            showAlertFor(title: "Error",
                         message: "The total of everyone's paid shares (\(differenceAmount.formattedCurrency)) is different than the total cost (\(expenseAmount.formattedCurrency))")
            return false
        }

        guard let selectedGroup, let userId = preference.user?.id else { return false }

        if let expense {
            return await handleUpdateExpenseAction(userId: userId, group: selectedGroup, expense: expense)
        } else {
            return await handleAddExpenseAction(userId: userId, group: selectedGroup)
        }
    }

    private func handleAddExpenseAction(userId: String, group: Groups) async -> Bool {
        let expense = Expense(name: expenseName.trimming(spaces: .leadingAndTrailing), amount: expenseAmount,
                              date: Timestamp(date: expenseDate), paidBy: selectedPayers,
                              addedBy: userId, updatedBy: userId, note: expenseNote,
                              splitTo: (splitType == .equally) ? selectedMembers : splitData.map({ $0.key }),
                              splitType: splitType, splitData: splitData)

        return await addExpense(group: group, expense: expense)
    }

    private func addExpense(group: Groups, expense: Expense) async -> Bool {
        guard let groupId = group.id else { return false }

        do {
            showLoader = true
            let newExpense = try await expenseRepository.addExpense(group: group, expense: expense, imageData: getImageData())
            let expenseInfo: [String: Any] = ["groupId": groupId, "expense": newExpense]
            NotificationCenter.default.post(name: .addExpense, object: nil, userInfo: expenseInfo)

            if !group.hasExpenses {
                selectedGroup?.hasExpenses = true
            }
            await updateGroupMemberBalance(expense: expense, updateType: .Add)

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
        var newExpense = expense
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

        newExpense.splitType = splitType
        newExpense.splitTo = (splitType == .equally) ? selectedMembers : splitData.map({ $0.key })
        newExpense.splitData = splitData

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
        oldExpense.splitData != expense.splitData || oldExpense.isActive != expense.isActive
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group = selectedGroup, let expenseId = expense.id else {
            showLoader = false
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group, type: .none)
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

    enum AddExpenseField {
        case expenseName
        case amount
    }
}
