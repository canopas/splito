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
            GroupSelectionView(name: viewModel.selectedGroup?.name ?? "Group") {
                viewModel.showGroupSelection = true
            }

            VStack(spacing: 16) {
                ExpenseDetailRow(imageName: "note.text", placeholder: "Enter a description",
                                 text: $viewModel.expenseName, date: $viewModel.expenseDate)
                ExpenseDetailRow(imageName: "indianrupeesign.square", placeholder: "0.00",
                                 text: $viewModel.expenseAmount, date: $viewModel.expenseDate, keyboardType: .numberPad)
                ExpenseDetailRow(imageName: "calendar", placeholder: "Expense date", forDatePicker: true,
                                 text: .constant(""), date: $viewModel.expenseDate)
            }
            .padding(.trailing, 20)

            PaidByView()
        }
        .padding(.horizontal, 20)
        .background(backgroundColor)
        .navigationBarTitle("Add an expense", displayMode: .inline)
        .sheet(isPresented: $viewModel.showGroupSelection) {
            ChooseGroupView(viewModel: ChooseGroupViewModel(selectedGroup: viewModel.selectedGroup) { group in
                viewModel.selectedGroup = group
            })
        }
        .sheet(isPresented: $viewModel.showMemberSelection) {
            ChoosePayerView(viewModel: ChoosePayerViewModel(groupId: viewModel.selectedGroup?.id ?? ""))
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Save")
                }
                .foregroundColor(primaryColor)
            }
        }
    }
}

struct ExpenseDetailRow: View {

    var imageName: String
    var placeholder: String
    var forDatePicker: Bool = false

    @Binding var text: String
    @Binding var date: Date

    var keyboardType: UIKeyboardType = .default

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
                DatePicker(placeholder, selection: $date, displayedComponents: .date)
                    .font(.subTitle2())
            } else {
                VStack {
                    TextField(placeholder, text: $text)
                        .font(.subTitle2())
                        .keyboardType(keyboardType)

                    Divider()
                        .background(Color.gray)
                        .frame(height: 1)
                }
            }
        }
    }
}

struct GroupSelectionView: View {

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

struct PaidByView: View {

    var body: some View {
        HStack(spacing: 10) {
            Text("Paid by")
                .font(.subTitle2())
                .foregroundColor(primaryText)

            Button {

            } label: {
                Text("you")
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
