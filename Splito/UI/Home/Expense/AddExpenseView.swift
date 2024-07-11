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
        VStack {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 25) {
                        VSpacer(80)

                        GroupSelectionView(name: viewModel.selectedGroup?.name ?? "Select group", onTap: viewModel.handleGroupBtnAction)

                        VStack(spacing: 16) {
                            ExpenseDetailRow(name: $viewModel.expenseName, amount: .constant(0), date: $viewModel.expenseDate, focusedField: $focusedField, imageName: "note.text", placeholder: "Enter a description", field: .expenseName)

                            ExpenseDetailRow(name: .constant(""), amount: $viewModel.expenseAmount, date: $viewModel.expenseDate, focusedField: $focusedField, imageName: "indianrupeesign.square", placeholder: "0.00", field: .expenseAmount, keyboardType: .decimalPad)

                            ExpenseDetailRow(name: .constant(""), amount: .constant(0), date: $viewModel.expenseDate, focusedField: $focusedField, imageName: "calendar", placeholder: "Expense date", forDatePicker: true)
                        }
                        .padding(.trailing, 20)

                        PaidByBottomView(splitType: viewModel.splitType, payerName: viewModel.payerName, onPayerTap: viewModel.handlePayerBtnAction,
                                         onSplitTypeTap: viewModel.handleSplitTypeBtnAction)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .background(backgroundColor)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitle(viewModel.expenseId == nil ? "Add expense" : "Edit expense", displayMode: .inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showGroupSelection) {
            NavigationStack {
                ChooseGroupView(viewModel: ChooseGroupViewModel(selectedGroup: viewModel.selectedGroup, onGroupSelection: viewModel.handleGroupSelection(group:)))
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
                    viewModel: ExpenseSplitOptionsViewModel(amount: viewModel.expenseAmount,
                                                            splitType: viewModel.splitType,
                                                            splitData: viewModel.splitData,
                                                            members: viewModel.groupMembers,
                                                            selectedMembers: viewModel.selectedMembers,
                                                            handleSplitTypeSelection: viewModel.handleSplitTypeSelection(members:splitData:splitType:))
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    viewModel.handleSaveAction {
                        dismiss()
                    }
                }
                .foregroundStyle(primaryColor)
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

    var imageName: String
    var placeholder: String
    var forDatePicker: Bool = false

    var field: AddExpenseViewModel.AddExpenseField?
    var keyboardType: UIKeyboardType = .default

    let maximumDate = Calendar.current.date(byAdding: .year, value: 0, to: Date())!

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: imageName)
                .resizable()
                .frame(width: 32, height: 32)
                .padding(12)
                .background(Color.clear)
                .foregroundStyle(primaryText.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(outlineColor, lineWidth: 1)
                )

            if forDatePicker {
                DatePicker(placeholder.localized, selection: $date, in: ...maximumDate, displayedComponents: .date)
                    .font(.subTitle2())
                    .onTapGesture(count: 99) {}
            } else {
                VStack {
                    if keyboardType == .default {
                        TextField(placeholder.localized, text: $name)
                            .font(.subTitle2())
                            .onTapGesture {
                                focusedField.wrappedValue = .expenseName
                            }
                            .focused(focusedField, equals: field)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField.wrappedValue = .expenseAmount
                            }
                    } else {
                        TextField("", value: $amount, formatter: numberFormatter)
                            .font(.subTitle2())
                            .keyboardType(keyboardType)
                            .onTapGesture {
                                focusedField.wrappedValue = .expenseAmount
                            }
                            .focused(focusedField, equals: field)
                    }

                    Divider()
                        .background(outlineColor)
                        .frame(height: 1)
                }
            }
        }
    }
}

private struct GroupSelectionView: View {

    var name: String
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("You and: ")
                .foregroundStyle(primaryText)

            Button {
                onTap()
            } label: {
                Text(name.localized)
                    .font(.subTitle2())
                    .foregroundStyle(secondaryText)
            }
            .buttonStyle(.scale)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 20).stroke(outlineColor, lineWidth: 1)
            )

            Spacer()
        }
    }
}

private struct PaidByBottomView: View {

    let splitType: SplitType
    let payerName: String
    var onPayerTap: () -> Void
    var onSplitTypeTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Paid by")

            PaidByBtnView(name: payerName, onTap: onPayerTap)

            Text("and split")

            PaidByBtnView(name: splitType == .equally ? "equally" : "unequally", onTap: onSplitTypeTap)
        }
        .font(.subTitle2())
        .foregroundStyle(primaryText)
    }
}

private struct PaidByBtnView: View {

    var name: String
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(name.localized)
                .font(.subTitle2())
                .foregroundStyle(secondaryText)
        }
        .buttonStyle(.scale)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(outlineColor, lineWidth: 1)
        )
    }
}

#Preview {
    AddExpenseView(viewModel: AddExpenseViewModel(router: .init(root: .AddExpenseView(expenseId: "", groupId: ""))))
}
