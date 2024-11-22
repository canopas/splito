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
    @Inject private var activityLogRepository: ActivityLogRepository

    public func addTransaction(group: Groups, transaction: Transactions, payer: AppUser, receiver: AppUser) async throws -> Transactions {
        let newTransaction = try await store.addTransaction(groupId: group.id ?? "", transaction: transaction)

        try await addActivityLogForTransaction(group: group, transaction: newTransaction, oldTransaction: transaction,
                                               type: .transactionAdded, members: (payer, receiver))

        return newTransaction
    }

    public func deleteTransaction(group: Groups, transaction: Transactions, payer: AppUser, receiver: AppUser) async throws -> Transactions {
        var updatedTransaction = transaction
        updatedTransaction.isActive = false  // Make transaction inactive
        updatedTransaction.updatedBy = preference.user?.id ?? ""
        return try await updateTransaction(group: group, transaction: updatedTransaction, oldTransaction: transaction,
                                           members: (payer, receiver), type: .transactionDeleted)
    }

    public func updateTransaction(group: Groups, transaction: Transactions, oldTransaction: Transactions,
                                  members: (payer: AppUser, receiver: AppUser), type: ActivityType) async throws -> Transactions {
        try await store.updateTransaction(groupId: group.id ?? "", transaction: transaction)

        try await addActivityLogForTransaction(group: group, transaction: transaction, oldTransaction: oldTransaction,
                                               type: type, members: members)

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
                    let context = ActivityLogContext(group: group, transaction: transaction, type: type, memberId: memberId,
                                                     currentUser: user, payerName: payerName, receiverName: receiverName)

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
        guard let groupId = context.group?.id, let transaction = context.transaction, let transactionId = transaction.id,
              let currentUser = context.currentUser else { return nil }

        let actionUserName = (context.memberId == currentUser.id) ? "You" : currentUser.nameWithLastInitial
        let amount: Double = (context.memberId == transaction.payerId) ? transaction.amount : (context.memberId == transaction.receiverId) ? -transaction.amount : 0

        return ActivityLog(type: context.type, groupId: groupId, activityId: transactionId, groupName: context.group?.name ?? "",
                           actionUserName: actionUserName, recordedOn: Timestamp(date: Date()), payerName: context.payerName,
                           receiverName: context.receiverName, amount: amount)
    }

    private func addActivityLog(context: ActivityLogContext) async -> Error? {
        if let activity = createActivityLogForTransaction(context: context), let memberId = context.memberId {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
            } catch {
                return error
            }
        }
        return nil
    }

    public func fetchTransactionsBy(groupId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (transactions: [Transactions], lastDocument: DocumentSnapshot?) {
        return try await store.fetchTransactionsBy(groupId: groupId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchTransactionBy(groupId: String, transactionId: String) async throws -> Transactions {
        return try await store.fetchTransactionsBy(groupId: groupId, transactionId: transactionId)
    }
}
