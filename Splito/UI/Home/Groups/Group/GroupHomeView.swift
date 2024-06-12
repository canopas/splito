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

    @StateObject var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            } else if case .hasExpense = viewModel.groupState {
                VSpacer(10)

                GroupExpenseListView(viewModel: viewModel)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle(viewModel.group?.name ?? "", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .fullScreenCover(isPresented: $viewModel.showSettleUpSheet) {
            GroupSettleUpRouteView(appRoute: Router(root: AppRoute.GroupSettleUpView(groupId: viewModel.group?.id ?? "")))
        }
        .fullScreenCover(isPresented: $viewModel.showBalancesSheet) {
            NavigationStack {
                GroupBalancesView(viewModel: GroupBalancesViewModel(groupId: viewModel.group?.id ?? ""))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showGroupTotalSheet) {
            NavigationStack {
                GroupTotalsView(viewModel: GroupTotalsViewModel(groupId: viewModel.group?.id ?? ""))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: viewModel.handleSearchOptionTap) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    Button(action: viewModel.handleSettingButtonTap) {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                .foregroundStyle(primaryColor)
            }
        }
        .onAppear(perform: viewModel.fetchGroupAndExpenses)
    }
}

private struct GroupExpenseListView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    @State private var isFocused: Bool = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if viewModel.showSearchBar {
                    SearchBar(text: $viewModel.searchedExpense, isFocused: $isFocused,
                              placeholder: "Search expenses", showCancelButton: true,
                              clearButtonMode: .never, onCancel: viewModel.onSearchBarCancelBtnTap)
                        .padding(.horizontal, 8)
                }

                List {
                    Group {
                        GroupExpenseHeaderView(viewModel: viewModel)

                        GroupOptionsListView(onSettleUpTap: viewModel.handleSettleUpBtnTap,
                                             onBalanceTap: viewModel.handleBalancesBtnTap,
                                             onTotalsTap: viewModel.handleTotalBtnTap)

                        if viewModel.groupExpenses.isEmpty {
                            ExpenseNotFoundView(geometry: geometry, searchedExpense: viewModel.searchedExpense)
                        } else {
                            ForEach(viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                                Section(header: Text(month).font(.subTitle2()).foregroundStyle(primaryText)) {
                                    ForEach(viewModel.groupExpenses[month]!, id: \.expense.id) { expense in
                                        GroupExpenseItemView(expenseWithUser: expense)
                                            .onTouchGesture {
                                                viewModel.handleExpenseItemTap(expenseId: expense.expense.id ?? "")
                                            }
                                            .swipeActions {
                                                DeleteExpenseBtnView {

                                                }
//                                                DeleteExpenseBtnView {
//                                                    viewModel.showDeleteExpenseConfirmation(expenseId: expense.expense.id)
//                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(backgroundColor)
                }
                .listStyle(.plain)
                .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .center)
            }
        }
    }
}

private struct ExpenseNotFoundView: View {

    let geometry: GeometryProxy
    let searchedExpense: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VSpacer()

            Text("No results found for \"\(searchedExpense)\"")
                .font(.subTitle2())
                .lineSpacing(2)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            VSpacer()
        }
        .frame(minHeight: geometry.size.height / 2, maxHeight: .infinity, alignment: .center)
    }
}

private struct DeleteExpenseBtnView: View {

    var handleDeleteExpense: () -> Void

    var body: some View {
        Button {
            handleDeleteExpense()
        } label: {
            Text("Delete")
        }
        .tint(.red)
    }
}

private struct GroupExpenseHeaderView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.group?.name ?? "")
                .font(.body2(28))
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

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.memberOwingAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                            let name = viewModel.getMemberDataBy(id: memberId)?.nameWithLastInitial ?? "Unknown"
                            GroupExpenseMemberOweView(name: name, amount: amount)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 24)
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
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(disableText.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.body1(17))
                    .foregroundStyle(primaryText)

                let amountText = isSettled ? "You paid for yourself" : "\(userName) paid \(expense.formattedAmount)"
                Text(amountText.localized)
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
        .padding(.top, 16)
        .padding(.horizontal, 6)
    }
}

private struct GroupOptionsListView: View {

    let onSettleUpTap: () -> Void
    let onBalanceTap: () -> Void
    let onTotalsTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            GroupOptionsButtonView(text: "Settle up", isForSettleUp: true, onTap: onSettleUpTap)

            GroupOptionsButtonView(text: "Balances", onTap: onBalanceTap)

            GroupOptionsButtonView(text: "Totals", onTap: onTotalsTap)
        }
        .padding(.vertical, 6)
    }
}

private struct GroupOptionsButtonView: View {

    let text: String
    var isForSettleUp = false

    let onTap: () -> Void

    var body: some View {
        Text(text.localized)
            .font(.subTitle2())
            .foregroundColor(isForSettleUp ? .white : primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isForSettleUp ? settleUpColor : backgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(outlineColor, lineWidth: 1)
            )
            .shadow(color: secondaryText.opacity(0.2), radius: 1, x: 0, y: 1)
            .onTouchGesture { onTap() }
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
