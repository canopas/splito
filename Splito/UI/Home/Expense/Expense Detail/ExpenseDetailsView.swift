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

    @ObservedObject var viewModel: ExpenseDetailsViewModel

    var body: some View {
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
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Details", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleDeleteBtnAction()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(primaryColor)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleEditBtnAction()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .foregroundStyle(primaryColor)
            }
        }
    }
}

private struct ExpenseHeaderView: View {

    let viewModel: ExpenseDetailsViewModel

    var username: String {
        let user = viewModel.getMemberDataBy(id: viewModel.expense?.addedBy ?? "")
        return viewModel.preference.user?.id == user?.id ? "You" : user?.nameWithLastInitial ?? "someone"
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
        .padding(.horizontal, 40)
    }
}

private struct ExpenseInfoView: View {

    let viewModel: ExpenseDetailsViewModel

    var expense: Expense? {
        viewModel.expense
    }

    var userName: String {
        let user = viewModel.getMemberDataBy(id: expense?.paidBy ?? "")
        return viewModel.preference.user?.id == user?.id ? "You" : user?.nameWithLastInitial ?? "someone"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {

            let mainImageHeight: CGFloat = 60
            let userImageUrl = viewModel.getMemberDataBy(id: expense?.paidBy ?? "")?.imageUrl
            MemberProfileImageView(imageUrl: userImageUrl, height: mainImageHeight)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(userName) paid \(expense?.formattedAmount ?? "nothing")")
                    .font(.body1(18))
                    .frame(height: mainImageHeight)

                VStack(alignment: .leading, spacing: 10) {
                    if let members = expense?.splitTo {
                        ForEach(members, id: \.self) { id in

                            if let member = viewModel.getMemberDataBy(id: id) {
                                let subImageHeight: CGFloat = 36

                                var memberName: String {
                                    return viewModel.preference.user?.id == member.id ? "You" : member.nameWithLastInitial
                                }

                                var splitAmount: String {
                                    let amount = expense?.amount ?? 0 / Double(expense?.splitTo.count ?? 1)
                                    return amount.formattedCurrency
                                }

                                var owes: String {
                                    return viewModel.preference.user?.id == member.id ? "owe" : "owes"
                                }

                                HStack(spacing: 10) {
                                    MemberProfileImageView(imageUrl: member.imageUrl, height: subImageHeight)
                                    Text("\(memberName) \(owes) \(splitAmount)")
                                }
                            }
                        }
                    }
                }
                .font(.body1())
                .foregroundStyle(secondaryText)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ExpenseDetailsView(viewModel: ExpenseDetailsViewModel(router: .init(root: .ExpenseDetailView(expenseId: "")), expenseId: ""))
}

struct ConnectionLineView: View {
    let fromPoint: CGPoint
    let toPoint: CGPoint
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: fromPoint)
            path.addLine(to: toPoint)
        }
        .stroke(color, lineWidth: 2)
    }
}

struct LabelView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
    }
}
