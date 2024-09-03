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
                                         showTransactionsOption: true,
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
                            GroupExpenseHeaderView(viewModel: viewModel)
                                .id("expense_list")

                            if viewModel.expenses.isEmpty {
                                EmptyStateView(geometry: geometry, minHeight: geometry.size.height - 250,
                                               onClick: viewModel.openAddExpenseSheet)
                            } else if !viewModel.groupExpenses.isEmpty {
                                let firstMonth = viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings).first

                                ForEach(viewModel.groupExpenses.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                                    Section(header: sectionHeader(month: month)) {
                                        ForEach(viewModel.groupExpenses[month] ?? [], id: \.expense.id) { expense in
                                            GroupExpenseItemView(expenseWithUser: expense,
                                                                 isLastItem: expense.expense == (viewModel.groupExpenses[month] ?? []).last?.expense)
                                            .onTouchGesture {
                                                viewModel.handleExpenseItemTap(expenseId: expense.expense.id ?? "")
                                            }
                                            .id(expense.expense.id)
                                            .swipeActions {
                                                Button {
                                                    viewModel.showExpenseDeleteAlert(expense: expense.expense)
                                                } label: {
                                                    Image(.deleteIcon)
                                                        .resizable()
                                                        .tint(.clear)
                                                }
                                            }
                                            .onAppear {
                                                if month == firstMonth && viewModel.groupExpenses[month]?.first?.expense.id == expense.expense.id {
                                                    viewModel.manageScrollToTopBtnVisibility(false)
                                                }
                                            }
                                            .onDisappear {
                                                if !viewModel.expenses.isEmpty && month == firstMonth && viewModel.groupExpenses[month]?.first?.expense.id == expense.expense.id {
                                                    viewModel.manageScrollToTopBtnVisibility(true)
                                                }
                                            }

                                            if expense.expense.id == viewModel.groupExpenses[month]?.last?.expense.id && viewModel.hasMoreExpenses {
                                                ProgressView()
                                                    .frame(maxWidth: .infinity, alignment: .center)
                                                    .onAppear {
                                                        viewModel.fetchMoreExpenses()
                                                    }
                                                    .padding(.vertical, 8)
                                            }
                                        }
                                    }
                                }
                            } else if viewModel.groupExpenses.isEmpty && viewModel.showSearchBar {
                                ExpenseNotFoundView(geometry: geometry, searchedExpense: viewModel.searchedExpense)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(surfaceColor)
                    }
                    .listStyle(.plain)
                    .overlay(alignment: .bottomTrailing) {
                        if viewModel.showScrollToTopBtn {
                            ScrollToTopButton {
                                withAnimation { scrollProxy.scrollTo("expense_list", anchor: .top) }
                            }.padding([.trailing, .bottom], 16)
                        }
                    }
                    .refreshable {
                        viewModel.fetchExpenses()
                    }
                }
            }.scrollBounceBehavior(.basedOnSize)
        }
    }

    private func sectionHeader(month: String) -> some View {
        HStack(spacing: 0) {
            Text(month)
                .font(.Header4())
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

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
            amount = expense.getCalculatedSplitAmountOf(member: user.id)
            isBorrowed = amount < 0
            isSettled = expense.paidBy.count == 1 && expense.paidBy.keys.contains(user.id) && expense.splitTo.contains(user.id) && expense.splitTo.count == 1
        } else if let userId = preference.user?.id, expense.paidBy.count > 1 && (expense.paidBy.keys.contains(userId) || expense.splitTo.contains(userId)) {
            userName = "\(expense.paidBy.count) people"
            if let userId = preference.user?.id {
                amount = expense.getCalculatedSplitAmountOf(member: userId)
                isBorrowed = amount < 0
                isSettled = amount == 0
            }
        } else {
            isBorrowed = true
            userName = expenseWithUser.user.nameWithLastInitial
            if let userId = preference.user?.id {
                amount = expense.getCalculatedSplitAmountOf(member: userId)
            }
            isInvolved = expense.splitTo.contains(where: { $0 == preference.user?.id })
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 0) {
                let dateComponents = expense.date.dateValue().dayAndMonthText
                VStack(spacing: 0) {
                    Text(dateComponents.month)
                        .font(.caption1())
                        .foregroundStyle(disableText)
                    Text(dateComponents.day)
                        .font(.Header4())
                        .foregroundStyle(primaryText)
                }
                .multilineTextAlignment(.center)
                .padding(.trailing, 8)

                let iconName: ImageResource = (isSettled || !isInvolved) ? .notInvolved : (isBorrowed ? .downArrow : .upArrow)
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
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
                                .font(.caption1())
                                .foregroundStyle(disableText)
                        }
                    }
                }
                .lineLimit(1)
                .foregroundStyle(isBorrowed ? alertColor : successColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

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
                VStack(alignment: .center, spacing: 16) {
                    Image(.tickmarkIcon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)

                    Text("You are all settled up in this group.")
                        .font(.subTitle1())
                        .foregroundStyle(primaryText)
                        .tracking(-0.2)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .center)
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
                    .foregroundStyle(disableText)

                Text("\(abs(viewModel.overallOwingAmount).formattedCurrency)")
                    .font(.body1())
                    .foregroundStyle(isDue ? alertColor : successColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Divider()
                .frame(width: 1)
                .background(dividerColor)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Your \(Date().nameOfMonth.lowercased()) spending")
                    .font(.body3())
                    .foregroundStyle(disableText)

                Text("\(abs(viewModel.currentMonthSpendingAmount).formattedCurrency)")
                    .font(.body1())
                    .foregroundStyle(primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(16)
        }
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double
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

            Image(systemName: "questionmark.circle")
                .resizable()
                .frame(width: 14, height: 14)
                .scaledToFit()
                .foregroundStyle(secondaryText)
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
                .foregroundStyle(primaryText)

            Text("No results were found that match your search criteria.")
                .font(.subTitle2())
                .foregroundStyle(disableText)
                .tracking(-0.2)
                .lineSpacing(4)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: geometry.size.height - 280, maxHeight: .infinity, alignment: .center)
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}
