//
//  ExpenseDetailsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/04/24.
//

import Data
import BaseStyle
import FirebaseFirestore

class ExpenseDetailsViewModel: BaseViewModel, ObservableObject {

    private let COMMENT_LIMIT = 10

    @Inject var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var commentRepository: CommentRepository

    @Published private(set) var expense: Expense?
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var expenseUsersData: [AppUser] = []

    @Published private(set) var viewState: ViewState = .loading

    @Published var comment: String = ""
    @Published var latestCommentId: String?
    @Published var expenseNote: String = ""
    @Published private(set) var groupImageUrl: String = ""

    @Published var showLoader: Bool = false
    @Published var showAddNoteEditor = false
    @Published var showImageDisplayView = false
    @Published var showEditExpenseSheet = false
    @Published private(set) var hasMoreComments: Bool = true

    var groupId: String
    var expenseId: String

    var group: Groups?
    let router: Router<AppRoute>
    private var lastDocument: DocumentSnapshot?

    init(router: Router<AppRoute>, groupId: String, expenseId: String) {
        self.router = router
        self.groupId = groupId
        self.expenseId = expenseId
        super.init()

        fetchInitialViewData()
        NotificationCenter.default.addObserver(self, selector: #selector(getUpdatedExpense(notification:)),
                                               name: .updateExpense, object: nil)
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroup()
            await fetchExpense()
            await fetchComments()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            group = try await groupRepository.fetchGroupBy(id: groupId)
            if let imageUrl = group?.imageUrl {
                groupImageUrl = imageUrl
            }
            LogD("ExpenseDetailsViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    private func fetchExpense() async {
        do {
            let expense = try await expenseRepository.fetchExpenseBy(groupId: groupId, expenseId: expenseId)
            await processExpense(expense: expense)
            LogD("ExpenseDetailsViewModel: \(#function) Expense fetched successfully.")
        } catch {
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch expense \(expenseId): \(error).")
            handleServiceError()
        }
    }

    private func processExpense(expense: Expense) async {
        var userData: [AppUser] = []

        var members = expense.splitTo
        for (payer, _) in expense.paidBy {
            members.append(payer)
        }
        members.append(expense.addedBy)

        for member in members.uniqued() {
            if let user = await fetchUserData(for: member) {
                userData.append(user)
            }
        }

        self.expense = expense
        self.expenseNote = expense.note ?? ""
        self.expenseUsersData = userData
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let member = try await userRepository.fetchUserBy(userID: userId)
            LogD("ExpenseDetailsViewModel: \(#function) Member fetched successfully.")
            return member
        } catch {
            viewState = .initial
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch member \(userId): \(error).")
            showToastForError()
            return nil
        }
    }

    private func fetchComments() async {
        guard hasMoreComments else {
            viewState = .initial
            return
        }

        do {
            let result = try await commentRepository.fetchCommentsBy(groupId: groupId, parentId: expenseId,
                                                                     limit: COMMENT_LIMIT, lastDocument: lastDocument)
            comments = lastDocument == nil ? result.data : (comments + result.data)
            await updateExpenseUsersData()
            hasMoreComments = !(result.data.count < COMMENT_LIMIT)
            lastDocument = result.lastDocument
            viewState = .initial
            LogD("ExpenseDetailsViewModel: \(#function) comments fetched successfully.")
        } catch {
            LogE("ExpenseDetailsViewModel: \(#function) Failed to fetch comments: \(error).")
            handleErrorState()
        }
    }

    private func updateExpenseUsersData() async {
        let commentedByUserIDs = Set(comments.map { $0.commentedBy })
        let expenseUserIDs = Set(expenseUsersData.map { $0.id })
        let missingUserIDs = commentedByUserIDs.subtracting(expenseUserIDs)

        if !missingUserIDs.isEmpty {
            for userId in missingUserIDs {
                if let user = await self.fetchUserData(for: userId) {
                    expenseUsersData.append(user)
                }
            }
        }
    }

    func loadMoreComments() {
        Task {
            await fetchComments()
        }
    }

    // MARK: - User Actions
    func getMemberDataBy(id: String) -> AppUser? {
        return expenseUsersData.first(where: { $0.id == id })
    }

    func handleAttachmentTap() {
        showImageDisplayView = true
    }

    func handleNoteTap() {
        guard let expense, expense.isActive, let userId = preference.user?.id,
              let group, group.members.contains(userId) else { return }
        showAddNoteEditor = true
    }

    func onSendCommentBtnTap() {
        guard let expense, let group, let userId = preference.user?.id,
              expense.isActive && group.isActive && group.members.contains(userId) else {
            showAlertFor(title: "Error",
                         message: "You do not have permission to add a comment on this expense, Sorry!")
            return
        }

        addComment()
    }

    private func addComment() {
        guard let expense, let group, let expenseId = expense.id, let userId = preference.user?.id else {
            LogE("ExpenseDetailsViewModel: \(#function) Missing required data for adding comment.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.showLoader = true
                let comment = Comment(parentId: expenseId, comment: self.comment.trimming(spaces: .leadingAndTrailing), commentedBy: userId)
                let newComment = try await self.commentRepository.addComment(group: group,
                                                                             expense: expense, comment: comment,
                                                                             existingCommenterIds: self.comments.map { $0.commentedBy })
                if let newComment {
                    self.comments.insert(newComment, at: 0)
                    self.latestCommentId = newComment.id
                    self.comment = ""
                    await self.updateExpenseUsersData()
                }
                self.showLoader = false
                LogD("ExpenseDetailsViewModel: \(#function) Expense comment added successfully.")
            } catch {
                self.showLoader = false
                LogE("ExpenseDetailsViewModel: \(#function) Failed to add expense comment: \(error).")
                self.showToastForError()
            }
        }
    }

    func handleEditBtnAction() {
        guard validateUserPermission(operationText: "edited", action: "edit"),
              validateGroupMembers(action: "edited") else { return }
        showEditExpenseSheet = true
    }

    func handleRestoreButtonAction() {
        showAlert = true
        alert = .init(title: "Restore expense",
                      message: "Are you sure you want to restore this expense?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in self?.restoreExpense() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func restoreExpense() {
        guard let group, group.isActive else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlertFor(title: "Error",
                                   message: "The group associated with this expense has been deleted, so it cannot be restored.")
            }
            return
        }

        guard var expense, let userId = preference.user?.id,
              validateUserPermission(operationText: "restored", action: "restored"),
              validateGroupMembers(action: "restored") else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.viewState = .loading
                expense.isActive = true
                expense.updatedBy = userId
                expense.updatedAt = Timestamp()

                self.expense = try await self.expenseRepository.updateExpense(group: group, expense: expense,
                                                                              oldExpense: expense, type: .expenseRestored)
                let expenseInfo: [String: Any] = ["groupId": groupId, "expense": expense]
                NotificationCenter.default.post(name: .addExpense, object: nil, userInfo: expenseInfo)
                await self.updateGroupMemberBalance(updateType: .Add)

                self.viewState = .initial
                LogD("ExpenseDetailsViewModel: \(#function) Expense restored successfully.")
                self.router.pop()
            } catch {
                LogE("ExpenseDetailsViewModel: \(#function) Failed to restore expense \(expenseId): \(error).")
                self.handleServiceError()
            }
        }
    }

    func handleDeleteButtonAction() {
        showAlert = true
        alert = .init(title: "Delete Expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in self?.deleteExpense() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func deleteExpense() {
        guard let group, let expense, validateUserPermission(operationText: "deleted", action: "delete"),
              validateGroupMembers(action: "deleted") else { return }

        Task {
            do {
                viewState = .loading
                self.expense = try await expenseRepository.deleteExpense(group: group, expense: expense)
                NotificationCenter.default.post(name: .deleteExpense, object: self.expense)
                await self.updateGroupMemberBalance(updateType: .Delete)

                viewState = .initial
                LogD("ExpenseDetailsViewModel: \(#function) Expense deleted successfully.")
                router.pop()
            } catch {
                viewState = .initial
                LogE("ExpenseDetailsViewModel: \(#function) Failed to delete expense \(expenseId): \(error).")
                showToastForError()
            }
        }
    }

    private func validateGroupMembers(action: String) -> Bool {
        guard let group, let expense else {
            LogE("ExpenseDetailsViewModel: \(#function) Missing required group or expense.")
            return false
        }

        let missingMemberIds = Set(expense.splitTo + Array(expense.paidBy.keys)).subtracting(group.members)

        if !missingMemberIds.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showAlertFor(message: "This expense involves a person who has left the group, and thus it can no longer be \(action). If you wish to change this expense, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func validateUserPermission(operationText: String, action: String) -> Bool {
        guard let userId = preference.user?.id, let group, group.members.contains(userId) else {
            DispatchQueue.main.async { [weak self] in
                self?.showAlertFor(title: "Error",
                                   message: "This expense could not be \(operationText). You do not have permission to \(action) this expense, Sorry!")
            }
            return false
        }
        return true
    }

    private func updateGroupMemberBalance(updateType: ExpenseUpdateType) async {
        guard var group, let userId = preference.user?.id, let expense else {
            LogE("ExpenseDetailsViewModel: \(#function) Group or expense information not found.")
            viewState = .initial
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
            group.balances = memberBalance
            group.updatedAt = Timestamp()
            group.updatedBy = userId
            try await groupRepository.updateGroup(group: group, type: .none)
            NotificationCenter.default.post(name: .updateGroup, object: group)
            LogD("ExpenseDetailsViewModel: \(#function) Member balance updated successfully.")
        } catch {
            viewState = .initial
            LogE("ExpenseDetailsViewModel: \(#function) Failed to update member balance for expense \(expenseId): \(error).")
            showToastForError()
        }
    }

    func getSplitAmount(for member: String) -> String {
        guard let expense else { return "" }
        let finalAmount = expense.getTotalSplitAmountOf(member: member)
        return finalAmount.formattedCurrency(expense.currencyCode)
    }

    @objc private func getUpdatedExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }
        Task { [weak self] in
            await self?.processExpense(expense: updatedExpense)
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

    private func handleErrorState() {
        if lastDocument == nil {
            handleServiceError()
        } else {
            viewState = .initial
            showToastForError()
        }
    }
}

// MARK: - View States
extension ExpenseDetailsViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
