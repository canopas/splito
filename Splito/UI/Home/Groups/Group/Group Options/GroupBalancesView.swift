//
//  GroupBalancesView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/04/24.
//

import SwiftUI
import Data
import BaseStyle

struct GroupBalancesView: View {

    @ObservedObject var viewModel: GroupBalancesViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .frame(height: 1)
                            .background(outlineColor.opacity(0.4))

                        VSpacer(50)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.memberBalances, id: \.id) { memberBalance in
                                GroupBalanceItemView(memberBalance: memberBalance, viewModel: viewModel, toggleExpandBtn: viewModel.handleBalanceExpandView(id:))

                                Divider()
                                    .frame(height: 1)
                                    .background(outlineColor)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .interactiveDismissDisabled()
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .setNavigationTitle("Group balances")
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

private struct GroupBalanceItemView: View {

    let memberBalance: GroupMemberBalance
    let viewModel: GroupBalancesViewModel

    let toggleExpandBtn: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 15) {
                let mainImageHeight: CGFloat = 50
                let imageUrl = viewModel.getMemberImage(id: memberBalance.id)
                MemberProfileImageView(imageUrl: imageUrl, height: mainImageHeight)

                let hasDue = memberBalance.totalOwedAmount < 0
                let name = viewModel.getMemberName(id: memberBalance.id, needFullName: true)
                let owesOrGetsBack = hasDue ? "owes" : "gets back"
                Group {
                    Text(name)
                        .font(.Header4())

                    + Text(" \(owesOrGetsBack.localized) ")

                    + Text(memberBalance.totalOwedAmount.formattedCurrency)
                        .font(.body1(17))
                        .foregroundColor(hasDue ? amountBorrowedColor : amountLentColor)

                    + Text(" in total")
                }
                .lineSpacing(3)
                .font(.body1(16))
                .foregroundStyle(primaryText)

                Spacer()

                Image(systemName: memberBalance.isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(secondaryText.opacity(0.8))
                    .onTouchGesture {
                        withAnimation(Animation.easeInOut(duration: 0.3)) {
                            toggleExpandBtn(memberBalance.id)
                        }
                    }
            }
            .padding(.horizontal, 15)

            if memberBalance.isExpanded {
                GroupBalanceItemMemberView(id: memberBalance.id, balances: memberBalance.balances, viewModel: viewModel)
            }
        }
    }
}

private struct GroupBalanceItemMemberView: View {

    let id: String
    let balances: [String: Double]
    let viewModel: GroupBalancesViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            let mainImageHeight: CGFloat = 50
            HSpacer(mainImageHeight)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(balances.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                    let hasDue = amount < 0
                    let imageUrl = viewModel.getMemberImage(id: hasDue ? id : memberId)
                    let owesMemberName = viewModel.getMemberName(id: hasDue ? memberId : id)
                    let owedMemberName = viewModel.getMemberName(id: hasDue ? id : memberId)

                    HStack(alignment: .center, spacing: 10) {
                        let subImageHeight: CGFloat = 36
                        MemberProfileImageView(imageUrl: imageUrl, height: subImageHeight)

                        Group {
                            Text("\(owedMemberName) owes ")

                            + Text(amount.formattedCurrency)
                                .foregroundColor(hasDue ? amountBorrowedColor : amountLentColor)

                            + Text(" to \(owesMemberName)")
                        }
                        .font(.body1(16))
                        .foregroundStyle(secondaryText)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    GroupBalancesView(viewModel: GroupBalancesViewModel(groupId: ""))
}
