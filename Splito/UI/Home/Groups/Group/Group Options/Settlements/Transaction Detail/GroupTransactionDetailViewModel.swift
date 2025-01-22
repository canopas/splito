//
//  GroupTransactionDetailViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 17/06/24.
//

import Data
import FirebaseFirestore

class GroupTransactionDetailViewModel: BaseViewModel, ObservableObject {

    private let COMMENT_LIMIT = 10

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var commentRepository: CommentRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published var comment: String = ""
    @Published var latestCommentId: String?

    @Published var paymentNote: String = ""
    @Published var paymentReason: String?

    @Published private(set) var transaction: Transactions?
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var transactionUsersData: [AppUser] = []

    @Published private(set) var viewState: ViewState = .loading

    @Published var showLoader: Bool = false
    @Published var showAddNoteEditor = false
    @Published var showImageDisplayView = false
    @Published var showEditTransactionSheet = false
    @Published private(set) var hasMoreComments: Bool = true

    let groupId: String
    let transactionId: String
    var amountCurrency: String

    var group: Groups?
    let router: Router<AppRoute>
    private var lastDocument: DocumentSnapshot?

    init(router: Router<AppRoute>, groupId: String, transactionId: String) {
        self.router = router
        self.groupId = groupId
        self.transactionId = transactionId
        self.amountCurrency = Currency.defaultCurrency.code
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(getUpdatedTransaction(notification:)), name: .updateTransaction, object: nil)

        fetchInitialTransactionData()
    }

    func fetchInitialTransactionData() {
        Task {
            await fetchGroup()
            await fetchTransaction()
            await fetchComments()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            group = try await groupRepository.fetchGroupBy(id: groupId)
            LogD("GroupTransactionDetailViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupTransactionDetailViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    private func fetchTransaction() async {
        do {
            transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            amountCurrency = transaction?.currencyCode ?? (group?.defaultCurrencyCode ?? Currency.defaultCurrency.code)
            await setTransactionUsersData()
            LogD("GroupTransactionDetailViewModel: \(#function) Payment fetched successfully.")
        } catch {
            LogE("GroupTransactionDetailViewModel: \(#function) Failed to fetch payment \(transactionId): \(error).")
            handleServiceError()
        }
    }

    private func setTransactionUsersData() async {
        guard let transaction else {
            viewState = .initial
            return
        }

        var userData: [AppUser] = []
        var members: [String] = []

        members.append(transaction.payerId)
        members.append(transaction.receiverId)
        members.append(transaction.addedBy)

        for member in members.uniqued() {
            if let user = await self.fetchUserData(for: member) {
                userData.append(user)
            }
        }

        self.transactionUsersData = userData
        self.paymentNote = transaction.note ?? ""
        self.paymentReason = transaction.reason ?? ""
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        do {
            let user = try await userRepository.fetchUserBy(userID: userId)
            guard let user else {
                viewState = .initial
                return nil
            }
            LogD("GroupTransactionDetailViewModel: \(#function) Member fetched successfully.")
            return user
        } catch {
            viewState = .initial
            LogE("GroupTransactionDetailViewModel: \(#function) Failed to fetch member \(userId): \(error).")
            showToastForError()
            return nil
        }
    }

    private func fetchComments() async {
        guard hasMoreComments else {
            self.viewState = .initial
            return
        }

        do {
            let result = try await commentRepository.fetchCommentsBy(groupId: groupId, parentId: transactionId, limit: COMMENT_LIMIT,
                                                                     lastDocument: lastDocument, isForExpenseComment: false)
            comments = lastDocument == nil ? result.data : (comments + result.data)
            await updateTransactionUsersData()
            hasMoreComments = !(result.data.count < COMMENT_LIMIT)
            lastDocument = result.lastDocument
            viewState = .initial
            LogD("GroupTransactionDetailViewModel: \(#function) comments fetched successfully.")
        } catch {
            LogE("GroupTransactionDetailViewModel: \(#function) Failed to fetch comments: \(error).")
            handleErrorState()
        }
    }

    private func updateTransactionUsersData() async {
        let commentedByUserIDs = Set(comments.map { $0.commentedBy })
        let transactionUserIDs = Set(transactionUsersData.map { $0.id })
        let missingUserIDs = commentedByUserIDs.subtracting(transactionUserIDs)

        if !missingUserIDs.isEmpty {
            for userId in missingUserIDs {
                if let user = await self.fetchUserData(for: userId) {
                    transactionUsersData.append(user)
                }
            }
        }
    }

    func loadMoreComments() {
        Task {
            await fetchComments()
        }
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return transactionUsersData.first(where: { $0.id == id })
    }

    // MARK: - User Actions
    func handleAttachmentTap() {
        showImageDisplayView = true
    }

    func handleNoteTap() {
        guard let transaction, transaction.isActive, let userId = preference.user?.id,
              let group, group.members.contains(userId) else { return }
        showAddNoteEditor = true
    }

    func handleEditBtnAction() {
        guard validateUserPermission(operationText: "edited", action: "edit"), validateGroupMembers(action: "edited") else { return }
        showEditTransactionSheet = true
    }

    func onSendCommentBtnTap() {
        guard let transaction, let group, let userId = preference.user?.id,
              transaction.isActive && group.isActive && group.members.contains(userId) else {
            showAlertFor(title: "Error",
                         message: "You do not have permission to add a comment on this payment, Sorry!")
            return
        }

        addComment()
    }

    private func addComment() {
        guard let transaction, let group, let transactionId = transaction.id, let userId = preference.user?.id else {
            LogE("GroupTransactionDetailViewModel: \(#function) Missing required data for adding comment.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                self.showLoader = true
                let comment = Comment(parentId: transactionId,
                                      comment: self.comment.trimming(spaces: .leadingAndTrailing),
                                      commentedBy: userId)
                let addedComment = try await self.commentRepository.addComment(group: group, transaction: transaction, comment: comment,
                                                                               existingCommenterIds: self.comments.map { $0.commentedBy })

                if let addedComment {
                    self.comments.insert(addedComment, at: 0)
                    self.latestCommentId = addedComment.id
                    self.comment = ""
                    await self.updateTransactionUsersData()
                }
                self.showLoader = false
                LogD("GroupTransactionDetailViewModel: \(#function) Payment comment added successfully.")
            } catch {
                self.showLoader = false
                LogE("GroupTransactionDetailViewModel: \(#function) Failed to add payment comment: \(error).")
                self.showToastForError()
            }
        }
    }

    func handleRestoreButtonAction() {
        showAlert = true
        alert = .init(title: "Restore payment",
                      message: "Are you sure you want to restore this payment?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in self?.restoreTransaction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func restoreTransaction() {
        guard let group, group.isActive else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlertFor(title: "Error",
                                   message: "The group associated with this payment has been deleted, so it cannot be restored.")
            }
            return
        }

        guard var transaction, validateUserPermission(operationText: "restored", action: "restored"),
              validateGroupMembers(action: "restored") else { return }

        Task { [weak self] in
            guard let self, let userId = preference.user?.id, let payer = getMemberDataBy(id: transaction.payerId),
                  let receiver = getMemberDataBy(id: transaction.receiverId) else { return }
            do {
                self.viewState = .loading
                transaction.isActive = true
                transaction.updatedBy = userId
                transaction.updatedAt = Timestamp()

                self.transaction = try await self.transactionRepository.updateTransaction(group: group, transaction: transaction, oldTransaction: transaction, members: (payer, receiver), type: .transactionRestored)
                NotificationCenter.default.post(name: .addTransaction, object: self.transaction)
                await self.updateGroupMemberBalance(updateType: .Add)

                self.viewState = .initial
                LogD("GroupTransactionDetailViewModel: \(#function) Payment restored successfully.")
                self.router.pop()
            } catch {
                self.viewState = .initial
                LogE("GroupTransactionDetailViewModel: \(#function) Failed to restore payment \(transactionId): \(error).")
                self.showToastForError()
            }
        }
    }

    func handleDeleteBtnAction() {
        showAlert = true
        alert = .init(title: "Delete payment",
                      message: "Are you sure you want to delete this payment?",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { [weak self] in self?.deleteTransaction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func deleteTransaction() {
        guard let transaction, validateUserPermission(operationText: "deleted", action: "delete"),
              validateGroupMembers(action: "deleted") else { return }

        Task { [weak self] in
            guard let self, let group, let payer = getMemberDataBy(id: transaction.payerId),
                  let receiver = getMemberDataBy(id: transaction.receiverId) else { return }
            do {
                self.viewState = .loading
                self.transaction = try await self.transactionRepository.deleteTransaction(group: group, transaction: transaction,
                                                                                          payer: payer, receiver: receiver)
                NotificationCenter.default.post(name: .deleteTransaction, object: self.transaction)
                await self.updateGroupMemberBalance(updateType: .Delete)

                self.viewState = .initial
                LogD("GroupTransactionDetailViewModel: \(#function) Payment deleted successfully.")
                self.router.pop()
            } catch {
                self.viewState = .initial
                LogE("GroupTransactionDetailViewModel: \(#function) Failed to delete payment \(transactionId): \(error).")
                self.showToastForError()
            }
        }
    }

    private func validateGroupMembers(action: String) -> Bool {
        guard let group, let transaction else {
            LogE("GroupTransactionDetailViewModel: \(#function) Missing required group or transaction.")
            return false
        }

        if !(group.members.contains(transaction.payerId)) || !(group.members.contains(transaction.receiverId)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showAlertFor(message: "This payment involves a person who has left the group, and thus it can no longer be \(action). If you wish to change this payment, you must first add that person back to your group.")
            }
            return false
        }

        return true
    }

    private func validateUserPermission(operationText: String, action: String) -> Bool {
        guard let userId = preference.user?.id, let group, group.members.contains(userId) else {
            DispatchQueue.main.async { [weak self] in
                self?.showAlertFor(title: "Error",
                                   message: "This payment could not be \(operationText). You do not have permission to \(action) this payment, Sorry!")
            }
            return false
        }
        return true
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) async {
        guard var group, let userId = preference.user?.id, let transaction, let transactionId = transaction.id else {
            LogE("GroupTransactionDetailViewModel: \(#function) Group or payment information not found.")
            viewState = .initial
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            group.updatedAt = Timestamp()
            group.updatedBy = userId
            try await groupRepository.updateGroup(group: group, type: .none)
            NotificationCenter.default.post(name: .updateGroup, object: group)
            LogD("GroupTransactionDetailViewModel: \(#function) Member balance updated successfully.")
        } catch {
            viewState = .initial
            LogE("GroupTransactionDetailViewModel: \(#function) Failed to update member balance for payment \(transactionId): \(error).")
            showToastForError()
        }
    }

    @objc private func getUpdatedTransaction(notification: Notification) {
        guard let updatedTransaction = notification.object as? Transactions else { return }
        transaction = updatedTransaction
        paymentNote = updatedTransaction.note ?? ""
        paymentReason = updatedTransaction.reason ?? ""
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
extension GroupTransactionDetailViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
