//
//  TransactionRepository.swift
//  Data
//
//  Created by Amisha Italiya on 12/06/24.
//

import FirebaseFirestore

public class TransactionRepository: ObservableObject {

    @Inject private var store: TransactionStore
    @Inject private var preference: SplitoPreference
    @Inject private var storageManager: StorageManager
    @Inject private var activityLogRepository: ActivityLogRepository

    public func addTransaction(group: Groups, transaction: Transactions,
                               members: (payer: AppUser, receiver: AppUser),
                               imageData: Data?) async throws -> Transactions {
        // Generate a new document ID for the payment
        let groupId = group.id ?? ""
        let transactionDocument = try await store.getNewTransactionDocument(groupId: groupId)

        var newTransaction = transaction
        newTransaction.id = transactionDocument.documentID

        // If image data is provided, upload the image and update the payment's imageUrl
        if let imageData {
            let imageUrl = try await uploadImage(imageData: imageData, transaction: newTransaction)
            newTransaction.imageUrl = imageUrl
        }

        try await store.addTransaction(document: transactionDocument, transaction: newTransaction)
        try await addActivityLogForTransaction(group: group, transaction: newTransaction, oldTransaction: transaction,
                                               type: .transactionAdded, members: members)
        return newTransaction
    }

    public func deleteTransaction(group: Groups, transaction: Transactions,
                                  payer: AppUser, receiver: AppUser) async throws -> Transactions {
        var updatedTransaction = transaction
        updatedTransaction.isActive = false  // Make transaction inactive
        updatedTransaction.updatedBy = preference.user?.id ?? ""
        updatedTransaction.updatedAt = Timestamp()
        return try await updateTransaction(group: group, transaction: updatedTransaction,
                                           oldTransaction: transaction, members: (payer, receiver),
                                           type: .transactionDeleted)
    }

    public func updateTransactionWithImage(imageData: Data?, newImageUrl: String?, group: Groups, transaction: (new: Transactions, old: Transactions), members: (payer: AppUser, receiver: AppUser)) async throws -> Transactions {
        var updatedTransaction = transaction.new

        // If image data is provided, upload the new image and update the imageUrl
        if let imageData {
            let uploadedImageUrl = try await uploadImage(imageData: imageData, transaction: updatedTransaction)
            updatedTransaction.imageUrl = uploadedImageUrl
        } else if let currentUrl = updatedTransaction.imageUrl, newImageUrl == nil {
            // If there's a current image URL and we want to remove it, delete the image and set imageUrl empty
            try await storageManager.deleteAttachment(attachmentUrl: currentUrl)
            updatedTransaction.imageUrl = ""
        } else if let newImageUrl {
            // If a new image URL is explicitly passed, update it
            updatedTransaction.imageUrl = newImageUrl
        }

        guard hasTransactionChanged(updatedTransaction, oldTransaction: transaction.old) else { return updatedTransaction }
        return try await updateTransaction(group: group, transaction: updatedTransaction,
                                           oldTransaction: transaction.old, members: members,
                                           type: .transactionUpdated)
    }

    private func uploadImage(imageData: Data, transaction: Transactions) async throws -> String {
        guard let transactionId = transaction.id else { return "" }
        return try await storageManager.uploadAttachment(for: .payment, id: transactionId, attachmentData: imageData) ?? ""
    }

    private func hasTransactionChanged(_ transaction: Transactions, oldTransaction: Transactions) -> Bool {
        return oldTransaction.payerId != transaction.payerId || oldTransaction.receiverId != transaction.receiverId ||
        oldTransaction.updatedBy != transaction.updatedBy || oldTransaction.note != transaction.note ||
        oldTransaction.imageUrl != transaction.imageUrl || oldTransaction.reason != transaction.reason ||
        oldTransaction.amount != transaction.amount || oldTransaction.date.dateValue() != transaction.date.dateValue() ||
        oldTransaction.updatedAt?.dateValue() != transaction.updatedAt?.dateValue() ||
        oldTransaction.isActive != transaction.isActive
    }

    public func updateTransaction(group: Groups, transaction: Transactions, oldTransaction: Transactions,
                                  members: (payer: AppUser, receiver: AppUser), type: ActivityType) async throws -> Transactions {
        try await store.updateTransaction(groupId: group.id ?? "", transaction: transaction)
        try await addActivityLogForTransaction(group: group, transaction: transaction,
                                               oldTransaction: oldTransaction, type: type, members: members)
        return transaction
    }

    private func addActivityLogForTransaction(group: Groups, transaction: Transactions, oldTransaction: Transactions,
                                              type: ActivityType, members: (payer: AppUser, receiver: AppUser)) async throws {
        guard let user = preference.user, type != .none else { return }

        var throwableError: Error?
        let involvedUserIds = Set([transaction.addedBy, transaction.payerId, transaction.receiverId, transaction.updatedBy])

        await withTaskGroup(of: Error?.self) { taskGroup in
            for memberId in involvedUserIds {
                taskGroup.addTask { [weak self] in
                    guard let self else { return nil }
                    let payerName = (user.id == transaction.payerId && memberId == transaction.payerId) ? (user.id == transaction.addedBy ? "You" : "you") : (memberId == transaction.payerId) ? "you" : members.payer.nameWithLastInitial
                    let receiverName = (memberId == transaction.receiverId) ? "you" : (memberId == transaction.receiverId) ? "you" : members.receiver.nameWithLastInitial
                    let context = ActivityLogContext(group: group, transaction: transaction, type: type,
                                                     memberId: memberId, currentUser: user, payerName: payerName,
                                                     receiverName: receiverName, paymentReason: transaction.reason)

                    return await self.addActivityLog(context: context)
                }
            }

            for await error in taskGroup {
                if let error {
                    throwableError = error
                    taskGroup.cancelAll()
                    break
                }
            }
        }

        if let throwableError {
            throw throwableError
        }
    }

    private func createActivityLogForTransaction(context: ActivityLogContext) -> ActivityLog? {
        guard let groupId = context.group?.id, let transaction = context.transaction,
              let transactionId = transaction.id, let currentUser = context.currentUser else { return nil }

        let actionUserName = (context.memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial
        let amount: Double = (context.memberId == transaction.payerId) ? transaction.amount : (context.memberId == transaction.receiverId) ? -transaction.amount : 0

        return ActivityLog(type: context.type, groupId: groupId, activityId: transactionId,
                           groupName: context.group?.name ?? "", actionUserName: actionUserName,
                           recordedOn: Timestamp(date: Date()), payerName: context.payerName,
                           receiverName: context.receiverName, paymentReason: context.paymentReason,
                           amount: amount, amountCurrency: transaction.currencyCode)
    }

    private func addActivityLog(context: ActivityLogContext) async -> Error? {
        if let activity = createActivityLogForTransaction(context: context), let memberId = context.memberId {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                LogD("TransactionRepository: \(#function) Activity log added successfully for \(memberId).")
            } catch {
                LogE("TransactionRepository: \(#function) Failed to add activity log for \(memberId): \(error).")
                return error
            }
        }
        return nil
    }

    public func fetchTransactionsBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (transactions: [Transactions], lastDocument: DocumentSnapshot?) {
        try await store.fetchTransactionsBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchTransactions(groupId: String, startDate: Date?, endDate: Date) async throws -> [Transactions] {
        try await store.fetchTransactions(groupId: groupId, startDate: startDate, endDate: endDate)
    }

    public func fetchTransactionBy(groupId: String, transactionId: String) async throws -> Transactions {
        try await store.fetchTransactionsBy(groupId: groupId, transactionId: transactionId)
    }

    public func getTransactionsCount(groupId: String) async throws -> Int {
        try await store.getTransactionsCount(groupId: groupId)
    }
}
