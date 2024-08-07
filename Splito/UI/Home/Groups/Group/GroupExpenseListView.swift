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
                    GroupOptionsListView(isSettleUpEnable: (!viewModel.memberOwingAmount.isEmpty && viewModel.group?.members.count ?? 1 > 1),
                                         showTransactionsOption: !viewModel.transactions.isEmpty,
                                         onSettleUpTap: viewModel.handleSettleUpBtnTap,
                                         onTransactionsTap: viewModel.handleTransactionsBtnTap,
                                         onBalanceTap: viewModel.handleBalancesBtnTap,
                                         onTotalsTap: viewModel.handleTotalBtnTap)

                    if viewModel.showSearchBar {
                        SearchBar(text: $viewModel.searchedExpense, isFocused: isFocused, placeholder: "Search expenses")
                            .padding(.vertical, -7)
                            .padding(.horizontal, 3)
                            .overlay(content: {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(outlineColor, lineWidth: 1)
                            })
                            .focused(isFocused)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 16)
                            .onAppear(perform: onSearchBarAppear)
                    }

                    List {
                        Group {
                            if viewModel.groupExpenses.isEmpty {
                                ExpenseNotFoundView(geometry: geometry, searchedExpense: viewModel.searchedExpense)
                            } else {
                                GroupExpenseHeaderView(viewModel: viewModel)
                                    .id("expenseList")

                                let firstMonth = viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings).first

                                ForEach(viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                                    Section(header: sectionHeader(month: month)) {
                                        ForEach(viewModel.groupExpenses[month] ?? [], id: \.expense.id) { expense in
                                            GroupExpenseItemView(expenseWithUser: expense,
                                                                 isLastItem: expense.expense == (viewModel.groupExpenses[month] ?? []).last?.expense)
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
                        .listRowBackground(surfaceColor)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if viewModel.showScrollToTopBtn {
                            ScrollToTopButton {
                                withAnimation {
                                    scrollProxy.scrollTo("expenseList", anchor: .top)
                                }
                            }
                            .padding([.trailing, .bottom], 16)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func sectionHeader(month: String) -> some View {
        HStack(spacing: 0) {
            Text(month)
                .font(.Header4())
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Spacer()
        }
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}

private struct GroupExpenseItemView: View {

    @Inject var preference: SplitoPreference

    let expense: Expense
    let isLastItem: Bool

    private var amount = 0.0
    private var isInvolved = true
    private var isSettled = false
    private var isBorrowed = false
    private var userName: String = ""

    init(expenseWithUser: ExpenseWithUser, isLastItem: Bool) {
        self.expense = expenseWithUser.expense
        self.isLastItem = isLastItem

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
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                let dateComponents = expense.date.dateValue().dayAndMonthText
                VStack(spacing: 0) {
                    Text(dateComponents.month)
                        .font(.caption1())
                        .foregroundColor(disableText)
                    Text(dateComponents.day)
                        .font(.Header4())
                        .foregroundColor(primaryText)
                }
                .multilineTextAlignment(.center)
                .padding(.trailing, 8)

                Image(systemName: expense.paidBy.keys.contains(preference.user?.id ?? "") ? "arrow.up.forward" : "arrow.down.backward")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(primaryText)
                    .padding(12)
                    .background(container2Color)
                    .cornerRadius(8)
                    .padding(.trailing, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.name)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    if isInvolved {
                        let amountText = isSettled ? "You paid for yourself" : "\(userName) paid \(expense.formattedAmount)"
                        Text(amountText.localized)
                            .font(.body3())
                            .foregroundStyle(disableText)
                    } else {
                        Text("You were not involved")
                            .font(.body3())
                            .foregroundStyle(disableText)
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    if isSettled {
                        Text("no balance")
                            .font(.body1())
                            .foregroundStyle(disableText)
                    } else {
                        if isInvolved {
                            Text(isBorrowed ? "you borrowed" : "you lent")
                                .font(.caption1())

                            Text(amount.formattedCurrency)
                                .font(.body1())
                        } else {
                            Text("not involved")
                                .font(.body1())
                                .foregroundStyle(disableText)
                        }
                    }
                }
                .lineLimit(1)
                .foregroundStyle(isBorrowed ? alertColor : successColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)

            if !isLastItem {
                Divider()
                    .frame(height: 1)
                    .background(dividerColor)
            }
        }
    }
}

private struct GroupExpenseHeaderView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.overallOwingAmount == 0 {
                Text("You are all settled up in this group.")
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)
                    .padding(16)
            } else {
                GroupExpenseHeaderOverallView(viewModel: viewModel)

                Divider()
                    .frame(height: 1)
                    .background(dividerColor)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.memberOwingAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                        let name = viewModel.getMemberDataBy(id: memberId)?.nameWithLastInitial ?? "Unknown"
                        GroupExpenseMemberOweView(name: name, amount: amount,
                                                  isDebtSimplified: viewModel.group?.isDebtSimplified ?? false,
                                                  handleSimplifyInfoSheet: viewModel.handleSimplifyInfoSheet)
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(containerColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}

private struct GroupExpenseHeaderOverallView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            let isDue = viewModel.overallOwingAmount < 0

            VStack(alignment: .leading, spacing: 4) {
                Text("You \(isDue ? "owe overall" : "are overall owed")")
                    .font(.body3())
                    .foregroundColor(disableText)

                Text("\(abs(viewModel.overallOwingAmount).formattedCurrency)")
                    .font(.body1())
                    .foregroundColor(isDue ? alertColor : successColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Divider()
                .frame(width: 1)
                .background(dividerColor)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Your \(Date().dayOfMonth) spending")
                    .font(.body3())
                    .foregroundColor(disableText)

                Text("\(abs(viewModel.currentMonthSpendingAmount).formattedCurrency)")
                    .font(.body1())
                    .foregroundColor(primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(16)
        }
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double
    let isDebtSimplified: Bool

    let handleSimplifyInfoSheet: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if amount > 0 {
                Group {
                    Text("\(name.localized) owes you ")
                        .foregroundColor(disableText)
                    + Text("\(amount.formattedCurrency)")
                        .foregroundColor(successColor)
                }
                .font(.body3())
            } else if amount < 0 {
                Group {
                    Text("You owe \(name.localized) ")
                        .foregroundColor(disableText)
                    + Text("\(amount.formattedCurrency)")
                        .foregroundColor(alertColor)
                }
                .font(.body3())
            }

            if isDebtSimplified {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .scaledToFit()
                    .foregroundColor(secondaryText)
            }
        }
        .onTouchGesture(handleSimplifyInfoSheet)
    }
}

private struct ExpenseNotFoundView: View {

    let geometry: GeometryProxy
    let searchedExpense: String

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("No results found for \"\(searchedExpense)\"!")
                .font(.Header1())
                .foregroundColor(primaryText)

            Text("No results were found that match your search criteria.")
                .font(.subTitle2())
                .foregroundColor(disableText)
                .tracking(-0.2)
                .lineSpacing(4)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: geometry.size.height - 130, maxHeight: .infinity, alignment: .center)
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}
