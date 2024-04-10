//
//  AddExpenseView.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import SwiftUI
import BaseStyle

struct AddExpenseView: View {

    @ObservedObject var viewModel: AddExpenseViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 25) {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else {
                GroupSelectionView(name: viewModel.selectedGroup?.name ?? "Group") {
                    viewModel.showGroupSelection = true
                }

                VStack(spacing: 16) {
                    ExpenseDetailRow(imageName: "note.text", placeholder: "Enter a description",
                                     name: $viewModel.expenseName, amount: .constant(0), date: $viewModel.expenseDate)
                    ExpenseDetailRow(imageName: "indianrupeesign.square", placeholder: "0.00",
                                     name: .constant(""), amount: $viewModel.expenseAmount, date: $viewModel.expenseDate, keyboardType: .numberPad)
                    ExpenseDetailRow(imageName: "calendar", placeholder: "Expense date", forDatePicker: true,
                                     name: .constant(""), amount: .constant(0), date: $viewModel.expenseDate)
                }
                .padding(.trailing, 20)

                PaidByView(payerName: viewModel.payerName) {
                    viewModel.showPayerSelection = viewModel.selectedGroup != nil
                }
            }
        }
        .padding(.horizontal, 20)
        .background(backgroundColor)
        .navigationBarTitle("Add an expense", displayMode: .inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showGroupSelection) {
            ChooseGroupView(viewModel: ChooseGroupViewModel(selectedGroup: viewModel.selectedGroup) { group in
                viewModel.selectedGroup = group
                viewModel.selectedPayer = nil
            })
        }
        .sheet(isPresented: $viewModel.showPayerSelection) {
            ChoosePayerView(viewModel: ChoosePayerViewModel(groupId: viewModel.selectedGroup?.id ?? "", selectedPayer: viewModel.selectedPayer) { payer in
                viewModel.selectedPayer = payer
            })
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    viewModel.saveExpense {
                        dismiss()
                    }
                }
                .foregroundColor(primaryColor)
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
                .foregroundColor(primaryText)
                .frame(width: 32, height: 32)
                .padding(12)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(outlineColor, lineWidth: 1)
                )

            if forDatePicker {
                DatePicker(placeholder, selection: $date, in: ...maximumDate, displayedComponents: .date)
                    .font(.subTitle2())
            } else {
                VStack {
                    if keyboardType == .default {
                        TextField(placeholder, text: $name)
                            .font(.subTitle2())
                    } else {
                        TextField("Amount", value: $amount, formatter: NumberFormatter())
                            .font(.subTitle2())
                            .keyboardType(keyboardType)
                    }

                    Divider()
                        .background(Color.gray)
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
                .foregroundColor(primaryText)

            Button {
                onTap()
            } label: {
                Text(name)
                    .font(.subTitle2())
                    .foregroundColor(secondaryText)
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

private struct PaidByView: View {

    let payerName: String
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Paid by")
                .font(.subTitle2())
                .foregroundColor(primaryText)

            Button {
                onTap()
            } label: {
                Text(payerName)
                    .font(.subTitle2())
                    .foregroundColor(secondaryText)
            }
            .buttonStyle(.scale)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(outlineColor, lineWidth: 1)
            )

            Text("and split equally")
                .font(.subTitle2())
                .foregroundColor(primaryText)
        }
    }
}

#Preview {
    AddExpenseView(viewModel: AddExpenseViewModel(router: .init(root: .AddExpenseView)))
}
