//
//  ExpenseAddNoteView.swift
//  Splito
//
//  Created by Nirali Sonani on 27/11/24.
//

import SwiftUI
import BaseStyle

struct ExpenseAddNoteView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: ExpenseAddNoteViewModel

    @State private var tempNote: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Enter your note here...", text: $tempNote, axis: .vertical)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .focused($isFocused)
                .tint(primaryColor)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .navigationTitle("Add note")
        .navigationBarTitleDisplayMode(.inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onAppear {
            tempNote = viewModel.expenseNote
            isFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CancelButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                CheckmarkButton(showLoader: viewModel.showLoader) {
                    viewModel.expenseNote = tempNote.trimming(spaces: .leadingAndTrailing)
                    Task {
                        let isActionSucceed = await viewModel.handleSaveNoteAction()
                        if isActionSucceed {
                            dismiss()
                        } else {
                            viewModel.showSaveFailedError()
                        }
                    }
                }
            }
        }
    }
}

struct CancelButton: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Button("Cancel") {
            dismiss()
        }
        .foregroundStyle(.blue)
    }
}
