//
//  AddExpenseView.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import SwiftUI
import BaseStyle
import Data

private enum AddExpenseField {
    case expenseName
    case amount
}

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: AddExpenseViewModel

    @FocusState private var focusedField: AddExpenseField?

    var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        VSpacer(16)

                        ExpenseInfoView(viewModel: viewModel, focusedField: $focusedField)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                AddNoteImageFooterView(date: $viewModel.expenseDate, showImageDisplayView: $viewModel.showImageDisplayView,
                                       showImagePickerOptions: $viewModel.showImagePickerOptions, image: viewModel.expenseImage,
                                       imageUrl: viewModel.expenseImageUrl, isNoteEmpty: viewModel.expenseNote.isEmpty,
                                       handleNoteBtnTap: viewModel.handleNoteBtnTap, handleCameraTap: viewModel.handleCameraTap,
                                       handleAttachmentTap: viewModel.handleAttachmentTap,
                                       handleActionSelection: viewModel.handleActionSelection(_:))
            }
        }
        .task { focusedField = .expenseName }
        .onDisappear { focusedField = nil }
        .background(surfaceColor)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(viewModel.expenseId == nil ? "Add expense" : "Edit expense")
        .navigationBarTitleDisplayMode(.inline)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showGroupSelection) {
            NavigationStack {
                SelectGroupView(viewModel: SelectGroupViewModel(selectedGroup: viewModel.selectedGroup,
                                                                onGroupSelection: viewModel.handleGroupSelectionAction(group:)))
            }
        }
        .sheet(isPresented: $viewModel.showPayerSelection) {
            NavigationStack {
                ChoosePayerRouteView(appRoute: .init(
                    root: .ChoosePayerView(groupId: viewModel.selectedGroup?.id ?? "",
                                           amount: viewModel.expenseAmount,
                                           currency: viewModel.selectedCurrency.code,
                                           selectedPayer: viewModel.selectedPayers,
                                           onPayerSelection: viewModel.handlePayerSelection(payers:)))) {
                                               viewModel.showPayerSelection = false
                                           }
            }
        }
        .sheet(isPresented: $viewModel.showSplitTypeSelection) {
            NavigationStack {
                ExpenseSplitOptionsView(
                    viewModel:
                        ExpenseSplitOptionsViewModel(
                            amount: viewModel.expenseAmount, selectedCurrency: viewModel.selectedCurrency.code,
                            splitType: viewModel.splitType, splitData: viewModel.splitData,
                            members: viewModel.groupMembers, selectedMembers: viewModel.selectedMembers,
                            handleSplitTypeSelection: viewModel.handleSplitTypeSelectionAction(splitData:splitType:)
                        )
                )
            }
        }
        .sheet(isPresented: $viewModel.showAddNoteEditor) {
            NavigationStack {
                AddNoteView(viewModel: AddNoteViewModel(
                    group: viewModel.selectedGroup, expense: viewModel.expense, note: viewModel.expenseNote,
                    handleSaveNoteTap: { note, _ in
                        viewModel.handleNoteSaveBtnTap(note: note)
                    }
                ))
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square, sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.expenseImage, isPresented: $viewModel.showImagePicker)
        }
        .fullScreenCover(isPresented: $viewModel.showCurrencyPicker) {
            NavigationStack {
                CurrencyPickerView(selectedCurrency: $viewModel.selectedCurrency,
                                   isPresented: $viewModel.showCurrencyPicker)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CancelButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                CheckmarkButton(showLoader: viewModel.showLoader) {
                    Task {
                        let isActionSucceed = await viewModel.handleSaveAction()
                        if isActionSucceed {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

private struct ExpenseInfoView: View {

    @ObservedObject var viewModel: AddExpenseViewModel

    var focusedField: FocusState<AddExpenseField?>.Binding

    @FocusState var isAmountFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            ExpenseDetailRow(name: $viewModel.expenseName, focusedField: focusedField, subtitle: "With you and:",
                             inputValue: viewModel.selectedGroup?.name ?? "Select group",
                             showButton: true, onTap: viewModel.handleGroupBtnAction)

            ExpenseDetailRow(name: $viewModel.expenseName, focusedField: focusedField,
                             subtitle: "Description", field: .expenseName)

            AddAmountView(amount: $viewModel.expenseAmount, showCurrencyPicker: $viewModel.showCurrencyPicker,
                          selectedCurrencySymbol: viewModel.selectedCurrency.symbol, isAmountFocused: $isAmountFocused)
                .focused(focusedField, equals: .amount)

            HStack(alignment: .top, spacing: 16) {
                ExpenseDetailRow(name: $viewModel.expenseName, focusedField: focusedField, subtitle: "Paid by",
                                 inputValue: viewModel.payerName, onTap: viewModel.handlePayerBtnAction)

                ExpenseDetailRow(name: $viewModel.expenseName, focusedField: focusedField, subtitle: "Split option",
                                 inputValue: viewModel.splitType == .equally ? "Equally" : "Unequally",
                                 onTap: viewModel.handleSplitTypeBtnAction)
            }
        }
        .padding(.horizontal, 1)
    }
}

private struct ExpenseDetailRow: View {

    @Binding var name: String
    var focusedField: FocusState<AddExpenseField?>.Binding

    let subtitle: String
    var inputValue: String = ""
    var showButton: Bool = false
    var field: AddExpenseField?

    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            VStack(alignment: .leading, spacing: 0) {
                if field == .expenseName {
                    TextField("Enter a description", text: $name, onCommit: {
                        focusedField.wrappedValue = .amount
                    })
                    .font(.subTitle2())
                    .tint(primaryColor)
                    .foregroundStyle(primaryText)
                    .focused(focusedField, equals: field)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                } else {
                    HStack(spacing: 16) {
                        Text(inputValue.localized)
                            .font(.subTitle2())
                            .foregroundStyle(primaryText)

                        Spacer()

                        if showButton {
                            ScrollToTopButton(icon: "chevron.down", iconColor: disableText, bgColor: surfaceColor,
                                              size: (12, 12), padding: 0, onClick: onTap)
                        }
                    }
                }
            }
            .padding(16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outlineColor, lineWidth: 1)
            }
            .onTapGestureForced {
                onTap?()
            }
        }
    }
}

struct AddNoteImageFooterView: View {

    @Binding var date: Date
    @Binding var showImageDisplayView: Bool
    @Binding var showImagePickerOptions: Bool

    let image: UIImage?
    let imageUrl: String?
    let isNoteEmpty: Bool

    let handleNoteBtnTap: (() -> Void)
    let handleCameraTap: (() -> Void)
    let handleAttachmentTap: (() -> Void)
    let handleActionSelection: ((ActionsOfSheet) -> Void)

    var body: some View {
        Divider()
            .frame(height: 1)
            .background(dividerColor)

        HStack(spacing: 16) {
            Spacer()

            DatePickerView(date: $date)

            ImageAttachmentView(showImageDisplayView: $showImageDisplayView, image: image, imageUrl: imageUrl,
                                handleCameraTap: handleCameraTap, handleAttachmentTap: handleAttachmentTap)
            .confirmationDialog("", isPresented: $showImagePickerOptions, titleVisibility: .hidden) {
                MediaPickerOptionsView(image: image, imageUrl: imageUrl, handleActionSelection: handleActionSelection)
            }

            NoteButtonView(isNoteEmpty: isNoteEmpty, handleNoteBtnTap: handleNoteBtnTap)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

private struct ImageAttachmentView: View {

    @Binding var showImageDisplayView: Bool

    let image: UIImage?
    let imageUrl: String?

    let handleCameraTap: (() -> Void)
    let handleAttachmentTap: (() -> Void)

    var body: some View {
        HStack(spacing: 0) {
            if image != nil || (imageUrl != nil && !(imageUrl?.isEmpty ?? false)) {
                AttachmentContainerView(image: image, imageUrl: imageUrl)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGestureForced(perform: handleAttachmentTap)
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
            }

            Image(.cameraIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .onTouchGesture(handleCameraTap)
        }
        .background(container2Color)
        .cornerRadius(8)
        .navigationDestination(isPresented: $showImageDisplayView) {
            AttachmentZoomView(image: image, imageUrl: imageUrl)
        }
    }
}

private struct NoteButtonView: View {

    let isNoteEmpty: Bool

    let handleNoteBtnTap: (() -> Void)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                UIApplication.shared.endEditing()
                handleNoteBtnTap()
            } label: {
                Image(.noteIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .background(container2Color)
                    .cornerRadius(8)
            }

            if !isNoteEmpty {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
