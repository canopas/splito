//
//  GroupExpenseListView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupExpenseListView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    let isFocused: FocusState<Bool>.Binding
    let onSearchBarAppear: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.showSearchBar {
                        SearchBar(
                            text: $viewModel.searchedExpense,
                            isFocused: isFocused,
                            placeholder: "Search expenses",
                            showCancelButton: true,
                            clearButtonMode: .never,
                            onCancel: viewModel.onSearchBarCancelBtnTap
                        )
                        .padding(.horizontal, 8)
                        .onAppear(perform: onSearchBarAppear)
                    }

                    List {
                        Group {
                            GroupExpenseHeaderView(viewModel: viewModel)
                                .id("expenseList")

                            GroupOptionsListView(isSettleUpEnable: (!viewModel.memberOwingAmount.isEmpty && viewModel.group?.members.count ?? 1 > 1),
                                                 showTransactionsOption: !viewModel.transactions.isEmpty,
                                                 onSettleUpTap: viewModel.handleSettleUpBtnTap,
                                                 onTransactionsTap: viewModel.handleTransactionsBtnTap,
                                                 onBalanceTap: viewModel.handleBalancesBtnTap,
                                                 onTotalsTap: viewModel.handleTotalBtnTap)

                            if viewModel.groupExpenses.isEmpty {
                                ExpenseNotFoundView(geometry: geometry, searchedExpense: viewModel.searchedExpense)
                            } else {
                                let firstMonth = viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings).first

                                ForEach(viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                                    Section(header: sectionHeader(month: month)) {
                                        ForEach(viewModel.groupExpenses[month] ?? [], id: \.expense.id) { expense in
                                            GroupExpenseItemView(expenseWithUser: expense)
                                                .onTouchGesture {
                                                    viewModel.handleExpenseItemTap(expenseId: expense.expense.id ?? "")
                                                }
                                                .swipeActions {
                                                    Button("Delete") {
                                                        viewModel.showExpenseDeleteAlert(expenseId: expense.expense.id ?? "")
                                                    }
                                                    .tint(.red)
                                                }
                                                .onAppear {
                                                    if month == firstMonth && viewModel.groupExpenses[month]?.first?.expense.id == expense.expense.id {
                                                        viewModel.manageScrollToTopBtnVisibility(false)
                                                    }
                                                }
                                                .onDisappear {
                                                    if month == firstMonth && viewModel.groupExpenses[month]?.first?.expense.id == expense.expense.id {
                                                        viewModel.manageScrollToTopBtnVisibility(true)
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(backgroundColor)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if viewModel.showScrollToTopBtn {
                            ScrollToTopButton {
                                withAnimation {
                                    scrollProxy.scrollTo("expenseList", anchor: .top)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .leading)
                }
            }
        }
    }

    private func sectionHeader(month: String) -> some View {
        return Text(month)
            .font(.subTitle2())
            .foregroundStyle(primaryText)
            .padding(.bottom, 8)
            .padding(.horizontal, 20)
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

        if let user = preference.user, expense.paidBy.count == 1 && expense.paidBy.keys.contains(user.id) {
            userName = "You"
            amount = getCalculatedSplitAmount(member: user.id, expense: expense)
            isBorrowed = amount < 0
            isSettled = expense.paidBy.count == 1 && expense.paidBy.keys.contains(user.id) && expense.splitTo.contains(user.id) && expense.splitTo.count == 1
        } else if let userId = preference.user?.id, expense.paidBy.count > 1 && (expense.paidBy.keys.contains(userId) || expense.splitTo.contains(userId)) {
            userName = "\(expense.paidBy.count) people"
            if let userId = preference.user?.id {
                amount = getCalculatedSplitAmount(member: userId, expense: expense)
                isBorrowed = amount < 0
                isSettled = amount == 0
            }
        } else {
            isBorrowed = true
            userName = expenseWithUser.user.nameWithLastInitial
            if let userId = preference.user?.id {
                amount = getCalculatedSplitAmount(member: userId, expense: expense)
            }
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

                if isInvolved {
                    let amountText = isSettled ? "You paid for yourself" : "\(userName) paid \(expense.formattedAmount)"
                    Text(amountText.localized)
                        .font(.body1(12))
                        .foregroundStyle(secondaryText)
                } else {
                    Text("You were not involved")
                        .font(.body1(12))
                        .foregroundStyle(secondaryText)
                }
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
        .padding(.vertical, 8)
        .padding(.horizontal, 26)
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
                Text(viewModel.memberOwingAmount.isEmpty ? "You are all settled up in this group." : "You are settled up overall.")
                    .font(.subTitle2())
            }

            if viewModel.memberOwingAmount.count < 2, let member = viewModel.memberOwingAmount.first {
                let name = viewModel.getMemberDataBy(id: member.key)?.nameWithLastInitial ?? "Unknown"
                GroupExpenseMemberOweView(name: name, amount: member.value,
                                          isDebtSimplified: viewModel.group?.isDebtSimplified ?? false,
                                          handleSimplifyInfoSheet: viewModel.handleSimplifyInfoSheet)
            } else {
                if viewModel.overallOwingAmount != 0 {
                    let isDue = viewModel.overallOwingAmount < 0
                    Text("You \(isDue ? "owe" : "are owed") \(abs(viewModel.overallOwingAmount).formattedCurrency) overall")
                        .font(.subTitle2())
                        .foregroundColor(isDue ? amountBorrowedColor : amountLentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.memberOwingAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                        let name = viewModel.getMemberDataBy(id: memberId)?.nameWithLastInitial ?? "Unknown"
                        GroupExpenseMemberOweView(name: name, amount: amount,
                                                  isDebtSimplified: viewModel.group?.isDebtSimplified ?? false,
                                                  handleSimplifyInfoSheet: viewModel.handleSimplifyInfoSheet)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double
    let isDebtSimplified: Bool

    let handleSimplifyInfoSheet: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if amount > 0 {
                Group {
                    Text("\(name.localized) owes you ")
                        .foregroundColor(primaryText)
                    + Text("\(amount.formattedCurrency)")
                        .foregroundColor(amountLentColor)
                }
                .font(.body1(14))
            } else if amount < 0 {
                Group {
                    Text("You owe \(name.localized) ")
                        .foregroundColor(primaryText)
                    + Text("\(amount.formattedCurrency)")
                        .foregroundColor(amountBorrowedColor)
                }
                .font(.body1(14))
            }

            if isDebtSimplified {
                Button(action: handleSimplifyInfoSheet) {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .scaledToFit()
                        .foregroundColor(primaryText)
                }
            }
        }
    }
}

struct SimplifyInfoSheetView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VSpacer(24)

            Text("Why do I owe this person?")
                .font(.subTitle1())
                .foregroundStyle(primaryText)

            VSpacer(24)

            Group {
                Text("\"Simplify debts\" is ENABLED in this group. This feature shuffles \"who owes who\" to minimize repayments. For example:\n")

                Text("Ana borrows $10 from Bob\nBob borrows $10 from Charlie\n")

                Text("In a group with \"simplify debts\" enabled, Splito will tell Ana to repay Charlie $10. Bob does nothing. This is the most efficient way for the group to settle up. With simplify debts enabled, it's normal to owe someone who didn't directly loan you money.")
            }
            .font(.body1(14))
            .foregroundStyle(primaryText)
            .multilineTextAlignment(.center)

            VSpacer(40)
        }
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 20)
        .frame(minHeight: geometry.size.height / 2, maxHeight: .infinity, alignment: .center)
    }
}
