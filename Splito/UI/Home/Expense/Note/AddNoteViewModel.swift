//
//  AddNoteViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 27/11/24.
//

import Data
import BaseStyle
import Foundation

class AddNoteViewModel: BaseViewModel, ObservableObject {

    @Inject private var userRepository: UserRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published var note: String
    @Published private(set) var showLoader: Bool = false

    private let group: Groups?
    private let expense: Expense?
    private let payment: Transactions?
    private let handleSaveNoteTap: ((String) -> Void)?

    init(group: Groups?, expense: Expense? = nil, payment: Transactions? = nil,
         note: String, handleSaveNoteTap: ((String) -> Void)? = nil) {
        self.group = group
        self.expense = expense
        self.payment = payment
        self.note = note
        self.handleSaveNoteTap = handleSaveNoteTap
        super.init()
    }

    // MARK: - User Actions
    func showSaveFailedError() {
        self.showToastFor(toast: ToastPrompt(type: .error, title: "Oops", message: "Failed to save note."))
    }

    func handleSaveNoteAction() async -> Bool {
        if let handleSaveNoteTap {
            handleSaveNoteTap(note)
            return true
        }

        if let expense, expense.note != note {
            return await updateExpenseNote()
        } else if let payment, payment.note != note {
            return await updatePaymentNote()
        }

        return true
    }

    private func updateExpenseNote() async -> Bool {
        guard let group, let expense else { return false }

        do {
            showLoader = true
            var updatedExpense = expense
            updatedExpense.note = note

            updatedExpense = try await expenseRepository.updateExpense(group: group, expense: updatedExpense, oldExpense: expense, type: .expenseUpdated)
            NotificationCenter.default.post(name: .updateExpense, object: updatedExpense)

            showLoader = false
            LogD("AddNoteViewModel: \(#function) Expense note updated successfully.")
            return true
        } catch {
            showLoader = false
            LogE("AddNoteViewModel: \(#function) Failed to update expense note: \(error).")
            showToastForError()
            return false
        }
    }

    private func updatePaymentNote() async -> Bool {
        guard let group, let payment else { return false }

        do {
            showLoader = true
            let members = try await fetchMembers(payerId: payment.payerId, receiverId: payment.receiverId)
            guard let members else {
                showLoader = false
                return false
            }

            var updatedPayment = payment
            updatedPayment.note = note
            updatedPayment = try await transactionRepository.updateTransaction(group: group, transaction: updatedPayment,
                                                                               oldTransaction: payment, members: members,
                                                                               type: .transactionUpdated)
            NotificationCenter.default.post(name: .updateTransaction, object: updatedPayment)

            showLoader = false
            LogD("AddNoteViewModel: \(#function) Payment note updated successfully.")
            return true
        } catch {
            showLoader = false
            LogE("AddNoteViewModel: \(#function) Failed to update payment note: \(error).")
            showToastForError()
            return false
        }
    }

    private func fetchMembers(payerId: String, receiverId: String) async throws -> (payer: AppUser, receiver: AppUser)? {
        let payer = try await userRepository.fetchUserBy(userID: payerId)
        let receiver = try await userRepository.fetchUserBy(userID: receiverId)

        if let payer, let receiver {
            return (payer, receiver)
        }
        return nil
    }
}
