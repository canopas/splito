//
//  ExpenseDetailsView.swift
//  Splito
//
//  Created by Amisha Italiya on 17/04/24.
//

import SwiftUI
import BaseStyle
import Data

struct ExpenseDetailsView: View {

    @StateObject var viewModel: ExpenseDetailsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        VSpacer(20)

                        ExpenseHeaderView(viewModel: viewModel)

                        Divider()
                            .frame(height: 1)
                            .background(outlineColor)

                        ExpenseInfoView(viewModel: viewModel)

                        Divider()
                            .frame(height: 1)
                            .background(outlineColor)

                        VSpacer()
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Details", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .fullScreenCover(isPresented: $viewModel.showEditExpenseSheet) {
            NavigationStack {
                AddExpenseView(viewModel: AddExpenseViewModel(router: viewModel.router, expenseId: viewModel.expenseId))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleDeleteBtnAction()
                } label: {
                    Image(systemName: "trash")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .foregroundStyle(primaryColor)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleEditBtnAction()
                } label: {
                    Image(systemName: "pencil")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .foregroundStyle(primaryColor)
            }
        }
        .onAppear {
            viewModel.fetchExpense()
        }
    }
}

private struct ExpenseHeaderView: View {

    let viewModel: ExpenseDetailsViewModel

    var username: String {
        let user = viewModel.getMemberDataBy(id: viewModel.expense?.addedBy ?? "")
        return viewModel.preference.user?.id == user?.id ? "you" : user?.nameWithLastInitial ?? "someone"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.expense?.name ?? "Expense")
                .font(.body1(22))
                .foregroundStyle(primaryText)

            Text(viewModel.expense?.formattedAmount ?? "₹ 0")
                .font(.H1Text(36))
                .foregroundStyle(primaryText)

            Text("Added by \(username) on \(viewModel.expense?.date.dateValue().longDate ?? "Today")")
                .lineLimit(0)
                .font(.body1(17))
                .foregroundStyle(secondaryText)
                .padding(.top, 6)
        }
        .lineLimit(1)
        .padding(.horizontal, 30)
    }
}

private struct ExpenseInfoView: View {

    let viewModel: ExpenseDetailsViewModel

    var expense: Expense? {
        viewModel.expense
    }

    var userName: String {
        if expense?.paidBy.count ?? 0 > 1 {
            if let payerCount = expense?.paidBy.count {
                return "\(String(describing: payerCount)) people"
            }
            return "You"
        } else {
            let user = viewModel.getMemberDataBy(id: expense?.paidBy.first?.key ?? "")
            return viewModel.preference.user?.id == user?.id ? "You" : user?.nameWithLastInitial ?? "someone"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {

            let mainImageHeight: CGFloat = 60
            let userImageUrl = viewModel.getMemberDataBy(id: expense?.paidBy.first?.key ?? "")?.imageUrl
            MemberProfileImageView(imageUrl: userImageUrl, height: mainImageHeight)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(userName.localized) paid \(expense?.formattedAmount ?? "nothing")")
                    .font(.body1(18))
                    .frame(height: mainImageHeight)

                VStack(alignment: .leading, spacing: 10) {
                    if let paidBy = expense?.paidBy {
                        if paidBy.count > 1 {
                            ForEach(Array(paidBy.keys), id: \.self) { payerId in
                                if let payer = viewModel.getMemberDataBy(id: payerId) {
                                    var payerName: String {
                                        return viewModel.preference.user?.id == payer.id ? "You" : payer.nameWithLastInitial
                                    }
                                    var owes: String {
                                        return viewModel.preference.user?.id == payer.id ? "owe" : "owes"
                                    }

                                    HStack(spacing: 10) {
                                        let subImageHeight: CGFloat = 36
                                        MemberProfileImageView(imageUrl: payer.imageUrl, height: subImageHeight)

                                        let paidAmount = paidBy[payerId] ?? 0.0
                                        let splitAmount = viewModel.getSplitAmount(for: payerId)
                                        Text("\(payerName.localized) paid \(paidAmount.formattedCurrency) and \(owes) \(splitAmount)")
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.body1())
                .foregroundStyle(secondaryText)
                .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    if let members = expense?.splitTo {
                        ForEach(members, id: \.self) { id in
                            if expense?.paidBy.count ?? 0 < 2 || !(expense?.paidBy.keys.contains(id) ?? false) {
                                let subImageHeight: CGFloat = 36
                                if let member = viewModel.getMemberDataBy(id: id) {
                                    var memberName: String {
                                        return viewModel.preference.user?.id == member.id ? "You" : member.nameWithLastInitial
                                    }
                                    var owes: String {
                                        return viewModel.preference.user?.id == member.id ? "owe" : "owes"
                                    }

                                    HStack(spacing: 10) {
                                        MemberProfileImageView(imageUrl: member.imageUrl, height: subImageHeight)

                                        let splitAmount = viewModel.getSplitAmount(for: member.id)
                                        if let paidBy = expense?.paidBy, paidBy.count == 1, let payerId = paidBy.keys.first, payerId == id {
                                            Text("\(memberName.localized) \(owes) \(splitAmount)")
                                        } else {
                                            Text("\(memberName.localized) \(owes) \(splitAmount)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.body1())
                .foregroundStyle(secondaryText)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ExpenseDetailsView(viewModel: ExpenseDetailsViewModel(router: .init(root: .ExpenseDetailView(expenseId: "")), expenseId: ""))
}
