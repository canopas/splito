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

    var body: some View {
        ScrollView {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                VStack(spacing: 25) {
                    VSpacer(80)

                    GroupSelectionView(name: viewModel.selectedGroup?.name ?? "Select group", onTap: viewModel.handleGroupBtnAction)

                    VStack(spacing: 16) {
                        ExpenseDetailRow(imageName: "note.text", placeholder: "Enter a description",
                                         name: $viewModel.expenseName, amount: .constant(0), date: $viewModel.expenseDate)
                        ExpenseDetailRow(imageName: "indianrupeesign.square", placeholder: "0.00",
                                         name: .constant(""), amount: $viewModel.expenseAmount, date: $viewModel.expenseDate, keyboardType: .numberPad)
                        ExpenseDetailRow(imageName: "calendar", placeholder: "Expense date", forDatePicker: true,
                                         name: .constant(""), amount: .constant(0), date: $viewModel.expenseDate)
                    }
                    .padding(.trailing, 20)

                    PaidByBottomView(splitType: viewModel.splitType, payerName: viewModel.payerName, onPayerTap: viewModel.handlePayerBtnAction,
                                     onSplitTypeTap: viewModel.handleSplitTypeBtnAction)
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
                ChoosePayerView(viewModel: ChoosePayerViewModel(groupId: viewModel.selectedGroup?.id ?? "", selectedPayer: viewModel.selectedPayer, onPayerSelection: viewModel.handlePayerSelection(payer:)))
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
    }
}

private struct ExpenseDetailRow: View {

    var imageName: String
    var placeholder: String
    var forDatePicker: Bool = false

    @Binding var name: String
    @Binding var amount: Double
    @Binding var date: Date

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
                DatePicker(placeholder, selection: $date, in: ...maximumDate, displayedComponents: .date)
                    .font(.subTitle2())
            } else {
                VStack {
                    if keyboardType == .default {
                        TextField(placeholder.localized, text: $name)
                            .font(.subTitle2())
                    } else {
                        TextField("", value: $amount, formatter: NumberFormatter())
                            .font(.subTitle2())
                            .keyboardType(keyboardType)
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
