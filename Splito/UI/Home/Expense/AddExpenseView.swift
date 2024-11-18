//
//  AddExpenseView.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import SwiftUI
import BaseStyle
import Data

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: AddExpenseViewModel

    @FocusState private var focusedField: AddExpenseViewModel.AddExpenseField?

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
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, 16)
        .background(surfaceColor)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(viewModel.expenseId == nil ? "Add expense" : "Edit expense")
        .navigationBarTitleDisplayMode(.inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showGroupSelection) {
            NavigationStack {
                SelectGroupView(viewModel: SelectGroupViewModel(selectedGroup: viewModel.selectedGroup,
                                                                onGroupSelection: viewModel.handleGroupSelectionAction(group:)))
            }
        }
        .sheet(isPresented: $viewModel.showPayerSelection) {
            NavigationStack {
                ChoosePayerRouteView(appRoute: .init(root: .ChoosePayerView(groupId: viewModel.selectedGroup?.id ?? "",
                                                                            amount: viewModel.expenseAmount,
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
                            amount: viewModel.expenseAmount, splitType: viewModel.splitType, splitData: viewModel.splitData,
                            members: viewModel.groupMembers, selectedMembers: viewModel.selectedMembers,
                            handleSplitTypeSelection: viewModel.handleSplitTypeSelectionAction(members:splitData:splitType:)
                        )
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.blue)
            }
            ToolbarItem(placement: .topBarTrailing) {
                CheckmarkButton(showLoader: viewModel.showLoader) {
                    Task {
                        let isActionSucceed = await viewModel.handleSaveAction()
                        if isActionSucceed {
                            dismiss()
                        } else {
                            viewModel.showSaveFailedError()
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

    var focusedField: FocusState<AddExpenseViewModel.AddExpenseField?>.Binding

    var body: some View {
        VStack(spacing: 16) {
            ExpenseDetailRow(name: $viewModel.expenseName, date: $viewModel.expenseDate, focusedField: focusedField,
                             subtitle: "With you and:", inputValue: viewModel.selectedGroup?.name ?? "Select group",
                             showButton: true, onTap: viewModel.handleGroupBtnAction)

            ExpenseDetailRow(name: $viewModel.expenseName, date: $viewModel.expenseDate, focusedField: focusedField,
                             subtitle: "Description", field: .expenseName)

            AmountRowView(amount: $viewModel.expenseAmount, subtitle: "Amount")
                .onTapGesture {
                    focusedField.wrappedValue = .amount
                }
                .focused(focusedField, equals: .amount)

            ExpenseDetailRow(name: $viewModel.expenseName, date: $viewModel.expenseDate,
                             focusedField: focusedField, subtitle: "Date", field: .date)

            HStack(alignment: .top, spacing: 16) {
                ExpenseDetailRow(name: $viewModel.expenseName, date: $viewModel.expenseDate, focusedField: focusedField,
                                 subtitle: "Paid by", inputValue: viewModel.payerName, onTap: viewModel.handlePayerBtnAction)

                ExpenseDetailRow(name: $viewModel.expenseName, date: $viewModel.expenseDate, focusedField: focusedField,
                                 subtitle: "Spilt option", inputValue: viewModel.splitType == .equally ? "Equally" : "Unequally",
                                 onTap: viewModel.handleSplitTypeBtnAction)
            }
        }
        .padding(.horizontal, 1)
    }
}

private struct ExpenseDetailRow: View {

    @Binding var name: String
    @Binding var date: Date
    var focusedField: FocusState<AddExpenseViewModel.AddExpenseField?>.Binding

    let subtitle: String
    var inputValue: String = ""
    var showButton: Bool = false
    var field: AddExpenseViewModel.AddExpenseField?

    var onTap: (() -> Void)?

    @State private var showDatePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            VStack(alignment: .leading, spacing: 0) {
                if field == .date {
                    DatePickerRow(date: $date)
                } else if field == .expenseName {
                    TextField("Enter a description", text: $name)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)
                        .keyboardType(.default)
                        .onTapGesture {
                            focusedField.wrappedValue = .expenseName
                        }
                        .tint(primaryColor)
                        .focused(focusedField, equals: field)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField.wrappedValue = .amount
                        }
                } else {
                    HStack(spacing: 0) {
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

struct DatePickerRow: View {

    @Binding var date: Date

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }

    private let maximumDate = Calendar.current.date(byAdding: .year, value: 0, to: Date()) ?? Date()

    @State private var tempDate: Date
    @State private var showDatePicker = false

    init(date: Binding<Date>) {
        self._date = date
        self._tempDate = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        HStack {
            Text(dateFormatter.string(from: date))
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .onTapGesture {
            tempDate = date
            showDatePicker = true
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 0) {
                NavigationBarTopView(title: "Choose date", leadingButton: EmptyView(),
                    trailingButton: DismissButton(padding: (16, 0), foregroundColor: primaryText, onDismissAction: {
                        showDatePicker = false
                    })
                    .fontWeight(.regular)
                )
                .padding(.leading, 16)

                ScrollView {
                    DatePicker("", selection: $tempDate, in: ...maximumDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                        .padding(24)
                        .id(tempDate)
                }
                .scrollIndicators(.hidden)

                Spacer()

                PrimaryButton(text: "Done") {
                    date = tempDate
                    showDatePicker = false
                }
                .padding(16)
            }
            .background(surfaceColor)
        }
    }
}
