//
//  GroupBalancesView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/04/24.
//

import SwiftUI
import BaseStyle

struct GroupBalancesView: View {

    @StateObject var viewModel: GroupBalancesViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.onViewAppear)
            } else if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VSpacer(27)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.memberBalances, id: \.id) { memberBalance in
                                GroupBalanceItemView(memberBalance: memberBalance, viewModel: viewModel, toggleExpandBtn: viewModel.handleBalanceExpandView(id:))

                                if memberBalance.id != viewModel.memberBalances.last?.id {
                                    Divider()
                                        .frame(height: 1)
                                        .background(dividerColor)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(surfaceColor)
        .interactiveDismissDisabled()
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .fullScreenCover(isPresented: $viewModel.showSettleUpSheet) {
            NavigationStack {
                GroupPaymentView(
                    viewModel: GroupPaymentViewModel(
                        router: viewModel.router, transactionId: nil,
                        groupId: viewModel.groupId, payerId: viewModel.payerId ?? "",
                        receiverId: viewModel.receiverId ?? "",
                        amount: viewModel.amount ?? 0
                    )
                )
            }
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Group balances")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

@MainActor
private struct GroupBalanceItemView: View {

    let memberBalance: MembersCombinedBalance
    let viewModel: GroupBalancesViewModel

    let toggleExpandBtn: (String) -> Void

    var imageUrl: String {
        viewModel.getMemberImage(id: memberBalance.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                HStack(spacing: 16) {
                    MemberProfileImageView(imageUrl: imageUrl)

                    let hasDue = memberBalance.totalOwedAmount < 0
                    let name = viewModel.getMemberName(id: memberBalance.id, needFullName: true)
                    let owesOrGetsBack = hasDue ? "owes" : "gets back"

                    if memberBalance.totalOwedAmount == 0 {
                        Group {
                            Text(name)
                                .font(.subTitle2())
                            + Text(" is settled up")
                                .font(.body1())
                        }
                        .foregroundStyle(primaryText)
                    } else {
                        Group {
                            Text(name)
                                .font(.subTitle2())

                            + Text(" \(owesOrGetsBack.localized) ")

                            + Text(memberBalance.totalOwedAmount.formattedCurrency)
                                .foregroundColor(hasDue ? alertColor : successColor)

                            + Text(" in total")
                        }
                        .lineSpacing(4)
                        .font(.body1())
                        .foregroundStyle(primaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if memberBalance.totalOwedAmount != 0 {
                    ScrollToTopButton(icon: "chevron.down", iconColor: primaryText,
                                      bgColor: container2Color, showWithAnimation: true, size: (10, 7),
                                      isFirstGroupCell: memberBalance.isExpanded) {
                        toggleExpandBtn(memberBalance.id)
                    }
                    .onAppear {
                        if memberBalance.isExpanded {
                            toggleExpandBtn(memberBalance.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            if memberBalance.isExpanded {
                GroupBalanceItemMemberView(id: memberBalance.id, balances: memberBalance.balances, viewModel: viewModel)
            }
        }
    }
}

private struct GroupBalanceItemMemberView: View {
    let SUBIMAGEHEIGHT: CGFloat = 24

    let id: String
    let balances: [String: Double]
    let viewModel: GroupBalancesViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HSpacer(32)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(balances.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                    let hasDue = amount < 0
                    let imageUrl = viewModel.getMemberImage(id: memberId)
                    let owesMemberName = viewModel.getMemberName(id: hasDue ? memberId : id)
                    let owedMemberName = viewModel.getMemberName(id: hasDue ? id : memberId)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 16) {
                            MemberProfileImageView(imageUrl: imageUrl, height: SUBIMAGEHEIGHT)

                            Group {
                                Text("\(owedMemberName) owes ")

                                + Text(amount.formattedCurrency)
                                    .foregroundColor(hasDue ? alertColor : successColor)

                                + Text(" to \(owesMemberName)")
                            }
                            .font(.body3())
                            .foregroundStyle(disableText)
                        }

                        HStack(alignment: .center, spacing: 16) {
                            HSpacer(SUBIMAGEHEIGHT)

                            Button {
                                viewModel.handleSettleUpTap(payerId: hasDue ? id : memberId, receiverId: hasDue ? memberId : id, amount: amount)
                            } label: {
                                Text("Settle up")
                                    .font(.caption1())
                                    .foregroundStyle(primaryText)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 24)
                                    .background(container2Color)
                                    .cornerRadius(30)
                            }
                        }
                    }
                }
            }
        }
    }
}
