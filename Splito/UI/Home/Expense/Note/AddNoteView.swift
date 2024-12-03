//
//  AddNoteView.swift
//  Splito
//
//  Created by Nirali Sonani on 27/11/24.
//

import SwiftUI
import BaseStyle

struct AddNoteView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: AddNoteViewModel

    @State private var tempPaymentReason: String = ""

    @FocusState private var focusedField: AddNoteViewModel.AddNoteField?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let paymentReason = viewModel.paymentReason {
                NoteInputFieldView(
                    text: $tempPaymentReason, focusedField: $focusedField,
                    title: "Reason", placeholder: "Enter a reason for this payment",
                    axis: .horizontal, submitLabel: .next, field: .reason,
                    onSubmit: {
                        focusedField = .note
                    },
                    onAppear: {
                        tempPaymentReason = paymentReason.isEmpty ? "Payment" : paymentReason
                    }
                )
            }

            NoteInputFieldView(
                text: $viewModel.note, focusedField: $focusedField, title: "Note",
                placeholder: "Enter your note here...", field: .note,
                onAppear: { })

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .navigationTitle("Add note")
        .navigationBarTitleDisplayMode(.inline)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onAppear {
            focusedField = viewModel.paymentReason != nil ? .reason : .note
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CancelButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                CheckmarkButton(showLoader: viewModel.showLoader) {
                    Task {
                        let isActionSucceed = await viewModel.handleSaveNoteAction(tempPaymentReason: tempPaymentReason)
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

private struct NoteInputFieldView: View {

    @Binding var text: String
    var focusedField: FocusState<AddNoteViewModel.AddNoteField?>.Binding

    let title: String
    let placeholder: String
    var axis: Axis = .vertical
    var submitLabel: SubmitLabel = .return
    var field: AddNoteViewModel.AddNoteField

    var onSubmit: (() -> Void)?
    var onAppear: (() -> Void)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body3())
                .foregroundStyle(disableText)

            TextField(placeholder.localized, text: $text, axis: axis)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .autocorrectionDisabled()
                .padding(16)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                }
                .focused(focusedField, equals: field)
                .submitLabel(submitLabel)
                .onSubmit {
                    onSubmit?()
                }
        }
        .onAppear(perform: onAppear)
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
