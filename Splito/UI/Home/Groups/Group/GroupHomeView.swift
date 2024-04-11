//
//  GroupHomeView.swift
//  Splito
//
//  Created by Amisha Italiya on 05/03/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupHomeView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .noGroup = viewModel.groupState {
                CreateGroupState(viewModel: .constant(viewModel))
            } else if case .noMember = viewModel.groupState {
                AddMemberState(viewModel: .constant(viewModel))
            } else if case .hasMembers = viewModel.groupState {
                if case .noExpense = viewModel.groupExpenseState {
                    NoExpenseView()
                } else if case .hasExpense(let expenses) = viewModel.groupExpenseState {
                    GroupExpenseListView(expenses: expenses)
                }
            }
        }
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle(viewModel.group?.name ?? "", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleSettingButtonTap()
                } label: {
                    Image(systemName: "gearshape")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .foregroundColor(primaryColor)
            }
        }
    }
}

private struct GroupExpenseListView: View {

    let expenses: [ExpenseWithUser]
    var sortedExpenses: [ExpenseWithUser] = []
    var groupedExpenses: [String: [ExpenseWithUser]] = [:]

    init(expenses: [ExpenseWithUser]) {
        self.expenses = expenses
        sortedExpenses = expenses.sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }

        self.groupedExpenses = Dictionary(grouping: sortedExpenses) { expense in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: expense.expense.date.dateValue())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VSpacer(20)

                ForEach(groupedExpenses.keys.sorted(), id: \.self) { month in
                    Section(header:
                        Text(month)
                        .font(.subTitle4(14))
                    ) {
                        ForEach(groupedExpenses[month]!, id: \.self) { expense in
                            GroupExpenseItemView(expense: expense)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct GroupExpenseItemView: View {

    @Inject var preference: SplitoPreference

    let expense: ExpenseWithUser

    private var amount = 0.0
    private var isBorrowed = false
    private var userName: String = ""

    init(expense: ExpenseWithUser) {
        self.expense = expense
        if let user = preference.user, expense.user.id == user.id {
            userName = "You"

            isBorrowed = false
            let singleExpense = expense.expense.amount / Double(expense.expense.splitTo.count)
            amount = expense.expense.amount - singleExpense
        } else {
            let firstName = expense.user.firstName ?? ""
            let lastNameInitial = expense.user.lastName?.first.map { String($0) } ?? ""
            userName = firstName + (lastNameInitial.isEmpty ? "" : " \(lastNameInitial).")

            isBorrowed = true
            amount = expense.expense.amount / Double(expense.expense.splitTo.count)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(expense.expense.date.dateValue().shortDateWithMonth())
                .font(.body1())
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            Image(systemName: "doc.plaintext")
                .resizable()
                .frame(width: 26)
                .font(.system(size: 14).weight(.light))
                .foregroundColor(.white)
                .padding(6)
                .background(disableText.opacity(0.3))
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.expense.name)
                    .font(.body1(17))
                    .foregroundColor(primaryText)

                Text("\(userName) paid ₹ \(expense.expense.amount.formattedString())")
                    .font(.body1(12))
                    .foregroundColor(secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(isBorrowed ? "you borrowed" : "you lent")
                    .font(.body1(12))

                Text("₹ \(amount.formattedString())")
                    .font(.body1(16))
            }
            .foregroundColor(isBorrowed ? amountBorrowedColor : amountLentColor)
        }
        .padding(.horizontal, 6)
    }
}

private struct AddMemberState: View {

    @Binding var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You're the only one here!")
                .font(.subTitle1())
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleAddMemberClick()
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.fill.badge.plus")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 32, height: 30)

                    Text("Invite members")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 22)
    }
}

private struct CreateGroupState: View {

    @Binding var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You do not have any groups yet.")
                .font(.Header1(22))
                .foregroundColor(primaryText)

            Text("Groups make it easy to split apartment bills, share travel expenses, and more.")
                .font(.subTitle3(15))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleCreateGroupClick()
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 42, height: 22)

                    Text("Start a group")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 10)
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 22)
    }
}

private struct NoExpenseView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("No expenses here yet.")
                .font(.subTitle4(17))
                .foregroundColor(primaryText)

            Text("Tap the plus button from home screen to add an expense with any group.")
                .font(.body1(18))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
    }
}

#Preview {
    GroupHomeView(viewModel: GroupHomeViewModel(router: .init(root: .GroupHomeView(groupId: "")), groupId: ""))
}
