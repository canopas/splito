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
        VStack(spacing: 0) {
            if case .loading = viewModel.groupState {
                LoaderView()
            } else if case .noMember = viewModel.groupState {
                AddMemberState(viewModel: .constant(viewModel))
            } else if case .noExpense = viewModel.groupState {
                NoExpenseView()
            } else if case .settledUp = viewModel.groupState {
                ScrollView {
                    VSpacer(60)

                    GroupExpenseHeaderView(viewModel: viewModel)

                    VSpacer(80)

                    ExpenseSettledView()
                        .onTouchGesture(viewModel.setHasExpenseState)
                }
                .scrollIndicators(.hidden)
            } else if case .hasExpense = viewModel.groupState {
                VSpacer(10)
                GroupExpenseListView(viewModel: viewModel,
                                     onExpenseItemTap: viewModel.handleExpenseItemTap(expenseId:))
            }
        }
        .background(backgroundColor)
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
                .foregroundStyle(primaryColor)
            }
        }
    }
}

private struct GroupExpenseListView: View {

    let viewModel: GroupHomeViewModel
    let onExpenseItemTap: (String) -> Void

    var isSettledUp = false
    var groupedExpenses: [String: [ExpenseWithUser]] = [:]

    init(viewModel: GroupHomeViewModel, onExpenseItemTap: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.onExpenseItemTap = onExpenseItemTap

        self.groupedExpenses = Dictionary(grouping: viewModel.expenseWithUser.sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: expense.expense.date.dateValue())
        }

        isSettledUp = (viewModel.group?.members.count ?? 1) > 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VSpacer(10)

                GroupExpenseHeaderView(viewModel: viewModel)

                VSpacer(10)

                ForEach(groupedExpenses.keys.sorted(), id: \.self) { month in
                    Section(header: Text(month).font(.subTitle4(14))) {
                        ForEach(groupedExpenses[month]!, id: \.self) { expense in
                            GroupExpenseItemView(expenseWithUser: expense)
                                .onTouchGesture { onExpenseItemTap(expense.expense.id ?? "0") }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
    }
}

private struct GroupExpenseHeaderView: View {

    var viewModel: GroupHomeViewModel

    init(viewModel: GroupHomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.group?.name ?? "")
                .font(.subTitle1(26))
                .foregroundStyle(primaryText)

            if viewModel.overallOwingAmount == 0 {
                Text("You are all settled up in this group.") // no due or lent
            } else {
                if viewModel.memberOwingAmount.count < 2, let member = viewModel.memberOwingAmount.first {
                    let name = viewModel.getMemberDataBy(id: member.key)?.nameWithLastInitial ?? "Unknown"
                    GroupExpenseMemberOweView(name: name, amount: viewModel.overallOwingAmount)
                } else {
                    let isDue = viewModel.overallOwingAmount < 0
                    Text("You \(isDue ? "owe" : "are owed") \(viewModel.overallOwingAmount.formattedCurrency) overall")
                        .font(.subTitle2())
                        .foregroundStyle(isDue ? amountBorrowedColor : amountLentColor)

                    ForEach(viewModel.memberOwingAmount.keys.sorted(), id: \.self) { memberId in
                        let owesAmount = viewModel.memberOwingAmount[memberId] ?? 0.0
                        let name = viewModel.getMemberDataBy(id: memberId)?.nameWithLastInitial ?? "Unknown"
                        GroupExpenseMemberOweView(name: name, amount: owesAmount)
                    }
                }
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 20)
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double

    var body: some View {
        if amount > 0 {
            Group {
                Text("\(name) owes you ")
                    .foregroundColor(primaryText)
                + Text("\(amount.formattedCurrency)")
                    .foregroundColor(amountLentColor)
            }
            .font(.body1(14))
        } else if amount < 0 {
            Group {
                Text("You owe \(name) ")
                    .foregroundColor(primaryText)
                + Text("\(amount.formattedCurrency)")
                    .foregroundColor(amountBorrowedColor)
            }
            .font(.body1(14))
        }
    }
}

private struct GroupExpenseItemView: View {

    @Inject var preference: SplitoPreference

    let expense: Expense

    private var amount = 0.0
    private var isInvolved = true
    private var isSettled = false
    private var isBorrowed = false
    private var userName: String = ""

    init(expenseWithUser: ExpenseWithUser) {
        self.expense = expenseWithUser.expense

        if let user = preference.user, expenseWithUser.user.id == user.id {
            userName = "You"
            isBorrowed = false
            let singleExpense = expense.splitTo.count == 1 ? 0 : expense.amount / Double(expense.splitTo.count)
            amount = expense.amount - singleExpense
            isSettled = expense.paidBy == preference.user?.id && expense.splitTo.contains(preference.user?.id ?? "") && expense.splitTo.count == 1
        } else {
            isBorrowed = true
            userName = expenseWithUser.user.nameWithLastInitial
            amount = expense.amount / Double(expense.splitTo.count)
            isInvolved = expense.splitTo.contains(where: { $0 == preference.user?.id })
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(expense.date.dateValue().shortDateWithNewLine)
                .font(.body1())
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Image(systemName: "doc.plaintext")
                .resizable()
                .frame(width: 22)
                .font(.system(size: 14).weight(.light))
                .foregroundStyle(.white)
                .padding(6)
                .background(disableText.opacity(0.3))
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.body1(17))
                    .foregroundStyle(primaryText)

                let amountText = isSettled ? "You paid for yourself" : "\(userName) paid \(expense.formattedAmount)"
                Text(amountText)
                    .font(.body1(12))
                    .foregroundStyle(secondaryText)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if isSettled {
                    Text("no balance")
                        .font(.body1(12))
                        .foregroundStyle(secondaryText)
                } else {
                    if isInvolved {
                        Text(isBorrowed ? "you borrowed" : "you lent")
                            .font(.body1(12))

                        Text(amount.formattedCurrency)
                            .font(.body1(16))
                    } else {
                        Text("not involved")
                            .font(.body1(12))
                            .foregroundStyle(secondaryText)
                    }
                }
            }
            .lineLimit(1)
            .foregroundStyle(isBorrowed ? amountBorrowedColor : amountLentColor)
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
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleAddMemberClick()
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.fill.badge.plus")
                        .resizable()
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 30)

                    Text("Invite members")
                        .foregroundStyle(.white)
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
                .foregroundStyle(primaryText)

            Text("Groups make it easy to split apartment bills, share travel expenses, and more.")
                .font(.subTitle3(15))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleCreateGroupClick()
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 22)

                    Text("Start a group")
                        .foregroundStyle(.white)
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
                .foregroundStyle(primaryText)

            Text("Tap the plus button from home screen to add an expense with any group.")
                .font(.body1(18))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
    }
}

private struct ExpenseSettledView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("You are all settled up.")
                .foregroundStyle(primaryText)

            Text("Tap to show settled expenses")
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            VSpacer(20)

            Image(.checkMarkTick)
                .resizable()
                .frame(width: 90, height: 80)
        }
        .font(.body1(17))
        .padding(.horizontal, 30)
    }
}

#Preview {
    GroupHomeView(viewModel: GroupHomeViewModel(router: .init(root: .GroupHomeView(groupId: "")), groupId: ""))
}
