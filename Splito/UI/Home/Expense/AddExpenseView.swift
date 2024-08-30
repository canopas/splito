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

    @StateObject var viewModel: AddExpenseViewModel

    @Environment(\.dismiss) var dismiss

    @FocusState private var focusedField: AddExpenseViewModel.AddExpenseField?

    var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        VSpacer(16)

                        VStack(spacing: 16) {
                            ExpenseDetailRowWithBtn(name: viewModel.selectedGroup?.name ?? "Select group",
                                                    subtitle: "With you and:", onTap: viewModel.handleGroupBtnAction)

                            ExpenseDetailRow(name: $viewModel.expenseName, amount: .constant(0),
                                             date: $viewModel.expenseDate, focusedField: $focusedField,
                                             subtitle: "Expense description", placeholder: "Enter a description",
                                             field: .expenseName)

                            ExpenseDetailRow(name: .constant(""), amount: $viewModel.expenseAmount,
                                             date: $viewModel.expenseDate, focusedField: $focusedField,
                                             subtitle: "Amount of expense", placeholder: "0.00",
                                             field: .amount, keyboardType: .decimalPad)

                            ExpenseDetailRow(name: .constant(""), amount: .constant(0),
                                             date: $viewModel.expenseDate, focusedField: $focusedField,
                                             subtitle: "Date", placeholder: "Expense date")

                            ExpenseDetailRowWithBtn(name: viewModel.payerName, subtitle: "Paid by",
                                                    onTap: viewModel.handlePayerBtnAction)

                            ExpenseDetailRowWithBtn(name: "Select which people owe an equal split.",
                                                    subtitle: "Spilt options",
                                                    memberProfileUrls: viewModel.memberProfileUrls,
                                                    onTap: viewModel.handleSplitTypeBtnAction)
                        }
                        .padding(.horizontal, 1)
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
                                                                onGroupSelection: viewModel.handleGroupSelection(group:)))
            }
        }
        .sheet(isPresented: $viewModel.showPayerSelection) {
            NavigationStack {
                ChoosePayerRouteView(appRoute: .init(root: .ChoosePayerView(groupId: viewModel.selectedGroup?.id ?? "", amount: viewModel.expenseAmount, selectedPayer: viewModel.selectedPayers, onPayerSelection: viewModel.handlePayerSelection(payers:)))) {
                    viewModel.showPayerSelection = false
                }
            }
        }
        .sheet(isPresented: $viewModel.showSplitTypeSelection) {
            NavigationStack {
                ExpenseSplitOptionsView(
                    viewModel:
                        ExpenseSplitOptionsViewModel(
                            amount: viewModel.expenseAmount,
                            splitType: viewModel.splitType,
                            splitData: viewModel.splitData,
                            members: viewModel.groupMembers,
                            selectedMembers: viewModel.selectedMembers,
                            handleSplitTypeSelection: viewModel.handleSplitTypeSelection(members:splitData:splitType:)
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
                CheckmarkButton(onClick: {
                    viewModel.handleSaveAction {
                        dismiss()
                    }
                })
            }
        }
        .onAppear {
            focusedField = .expenseName
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

private struct ExpenseDetailRow: View {

    @Binding var name: String
    @Binding var amount: Double
    @Binding var date: Date
    var focusedField: FocusState<AddExpenseViewModel.AddExpenseField?>.Binding

    let subtitle: String
    let placeholder: String

    var field: AddExpenseViewModel.AddExpenseField?
    var keyboardType: UIKeyboardType = .default

    @State private var showDatePicker = false
    @State private var amountString: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            VStack(alignment: .leading, spacing: 0) {
                if field != .amount && field != .expenseName {
                    DatePickerRow(date: $date)
                } else {
                    if keyboardType == .default {
                        TextField(placeholder.localized, text: $name)
                            .font(.subTitle2())
                            .foregroundStyle(primaryText)
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
                        TextField(placeholder.localized, text: $amountString)
                            .font(.subTitle2())
                            .foregroundStyle(primaryText)
                            .onTapGesture {
                                focusedField.wrappedValue = .amount
                            }
                            .tint(primaryColor)
                            .focused(focusedField, equals: field)
                            .autocorrectionDisabled()
                            .keyboardType(keyboardType)
                            .onChange(of: amountString) { newValue in
                                if let value = Double(newValue) {
                                    amount = value
                                } else {
                                    amount = 0
                                }
                            }
                            .onAppear {
                                amountString = amount == 0 ? "" : String(format: "%.2f", amount)
                            }
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outlineColor, lineWidth: 1)
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

private struct ExpenseDetailRowWithBtn: View {

    let name: String
    let subtitle: String
    var memberProfileUrls: [String] = []

    let onTap: () -> Void

    private var visibleProfileUrls: [String] {
        Array(memberProfileUrls.prefix(5))
    }

    private var additionalMembersCount: Int {
        max(memberProfileUrls.count - 5, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    Text(name.localized)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    Spacer()

                    ScrollToTopButton(icon: "chevron.down", iconColor: disableText,
                                      bgColor: surfaceColor, size: (12, 12), padding: 0, onClick: onTap)
                }

                if !memberProfileUrls.isEmpty {
                    HStack(spacing: -10) {
                        ForEach(visibleProfileUrls, id: \.self) { imageUrl in
                            MemberProfileImageView(imageUrl: imageUrl, height: 26, defaultImageBgColor: containerColor)
                        }

                        if additionalMembersCount > 0 {
                            Text("+\(additionalMembersCount)")
                                .font(.caption1())
                                .foregroundStyle(primaryText)
                                .frame(width: 26, height: 26)
                                .background(containerColor)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outlineColor, lineWidth: 1)
            }
        }
        .onTapGestureForced(perform: onTap)
    }
}
