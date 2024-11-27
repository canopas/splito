//
//  ExpenseAddNoteViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 27/11/24.
//

import Data
import BaseStyle
import Foundation

class ExpenseAddNoteViewModel: BaseViewModel, ObservableObject {

    @Inject private var expenseRepository: ExpenseRepository

    @Published var expenseNote: String
    @Published private(set) var showLoader: Bool = false

    private let group: Groups?
    private let expense: Expense?
    private let handleSaveNoteTap: ((String) -> Void)?

    init(group: Groups?, expense: Expense?, expenseNote: String, handleSaveNoteTap: ((String) -> Void)? = nil) {
        self.group = group
        self.expense = expense
        self.expenseNote = expenseNote
        self.handleSaveNoteTap = handleSaveNoteTap
        super.init()
    }

    // MARK: - User Actions
    func showSaveFailedError() {
        self.showToastFor(toast: ToastPrompt(type: .error, title: "Oops", message: "Failed to save note."))
    }

    func handleSaveNoteAction() async -> Bool {
        if let handleSaveNoteTap {
            handleSaveNoteTap(expenseNote)
            return true
        }

        guard let expense, expense.note != expenseNote else { return true }
        return await updateExpenseNote()
    }

    private func updateExpenseNote() async -> Bool {
        guard let group, let expense else { return false }

        do {
            showLoader = true
            var updatedExpense = expense
            updatedExpense.note = expenseNote

            try await expenseRepository.updateExpense(group: group, expense: updatedExpense, oldExpense: expense, type: .expenseUpdated)
            NotificationCenter.default.post(name: .updateExpense, object: updatedExpense)

            showLoader = false
            LogD("ExpenseAddNoteViewModel: \(#function) Expense note updated successfully.")
            return true
        } catch {
            LogE("ExpenseAddNoteViewModel: \(#function) Failed to update expense note: \(error).")
            showToastForError()
            return false
        }
    }
}
