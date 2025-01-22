//
//  GroupBalancesView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/04/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupBalancesView: View {

    @StateObject var viewModel: GroupBalancesViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialBalancesData)
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
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .fullScreenCover(isPresented: $viewModel.showSettleUpSheet) {
            NavigationStack {
                GroupPaymentView(
                    viewModel: GroupPaymentViewModel(
                        router: viewModel.router, transactionId: nil,
                        groupId: viewModel.groupId, payerId: viewModel.payerId ?? "",
                        receiverId: viewModel.receiverId ?? "",
                        amount: viewModel.amount ?? 0,
                        currency: viewModel.amountCurrency ?? Currency.defaultCurrency.code
                    )
                )
            }
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Group balances")
            }
        }
    }
}

@MainActor
private struct GroupBalanceItemView: View {

    @Inject private var preference: SplitoPreference

    let memberBalance: MembersCombinedBalance
    let viewModel: GroupBalancesViewModel

    let toggleExpandBtn: (String) -> Void

    var imageUrl: String {
        viewModel.getMemberImage(id: memberBalance.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                let name = viewModel.getMemberName(id: memberBalance.id, needFullName: true)

                HStack(spacing: 16) {
                    MemberProfileImageView(imageUrl: imageUrl)

                    if memberBalance.totalOwedAmount.allSatisfy({ $0.value == 0 }) {
                        Group {
                            Text(name)
                                .font(.subTitle2())
                            + Text(" \(name == "You" ? "are" : "is") settled up")
                                .font(.body1())
                        }
                        .foregroundStyle(primaryText)
                    } else {
                        let positiveAmounts = memberBalance.totalOwedAmount.filter { $0.value > 0 }
                        let negativeAmounts = memberBalance.totalOwedAmount.filter { $0.value < 0 }

                        let positiveText = positiveAmounts.map { currency, amount in
                            amount.formattedCurrency(currency)
                        }.joined(separator: " + ")

                        let negativeText = negativeAmounts.map { currency, amount in
                            abs(amount).formattedCurrency(currency) // Use `abs` for positive display
                        }.joined(separator: " + ")

                        VStack(alignment: .leading, spacing: 0) {
                            if !positiveAmounts.isEmpty {
                                let getBackText = (memberBalance.id == preference.user?.id) ? "get back" : "gets back"
                                Text("\(name) \(getBackText) ")
                                    .font(.subTitle2())

                                + Text(positiveText)
                                    .foregroundColor(successColor)

                                + Text(" in total")
                            }

                            if !negativeAmounts.isEmpty {
                                let oweText = (memberBalance.id == preference.user?.id) ? "owe" : "owes"
                                Text("\(name) \(oweText) ")
                                    .font(.subTitle2())

                                + Text(negativeText)
                                    .foregroundColor(errorColor)

                                + Text(" in total")
                            }
                        }
                        .lineSpacing(4)
                        .font(.body1())
                        .foregroundStyle(primaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if memberBalance.totalOwedAmount.contains(where: { $0.value != 0 }) {
                    ScrollToTopButton(
                        icon: "chevron.down", iconColor: primaryText, bgColor: container2Color,
                        showWithAnimation: true, size: (10, 7), isFirstGroupCell: memberBalance.isExpanded,
                        onClick: {
                            toggleExpandBtn(memberBalance.id)
                        }
                    )
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
    let SUB_IMAGE_HEIGHT: CGFloat = 24

    @Environment(\.dismiss) var dismiss

    @Inject private var preference: SplitoPreference

    let id: String
    let balances: [String: [String: Double]]
    let viewModel: GroupBalancesViewModel

    @State private var showShareReminderSheet = false
    @State private var reminderText: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HSpacer(32)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(balances.sorted(by: { $0.key < $1.key }), id: \.key) { (currency, memberBalances) in
                    ForEach(memberBalances.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                        let hasDue = amount < 0
                        let imageUrl = viewModel.getMemberImage(id: memberId)
                        let owesMemberName = viewModel.getMemberName(id: hasDue ? memberId : id)
                        let owedMemberName = viewModel.getMemberName(id: hasDue ? id : memberId)
                        let owesText = ((hasDue ? id : memberId) == preference.user?.id) ? "owe" : "owes"

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 16) {
                                MemberProfileImageView(imageUrl: imageUrl, height: SUB_IMAGE_HEIGHT, scaleEffect: 0.6)

                                Group {
                                    Text("\(owedMemberName.capitalized) \(owesText.localized) ")
                                    + Text(amount.formattedCurrency(currency))
                                        .foregroundColor(hasDue ? errorColor : successColor)
                                    + Text(" to \(owesMemberName)")
                                }
                                .font(.body3())
                                .foregroundStyle(disableText)
                            }

                            RemindAndSettleBtnView(
                                handleRemindTap: {
                                    let oweText = ((hasDue ? id : memberId) == preference.user?.id) ? "owe" :
                                    (memberId == preference.user?.id || id == preference.user?.id) ? "owes" : ""
                                    reminderText = generateReminderText(owedMemberName: owedMemberName, owesText: oweText,
                                                                        amount: amount, currency: currency,
                                                                        owesMemberName: owesMemberName)
                                    showShareReminderSheet = true
                                },
                                handleSettleUpTap: {
                                    viewModel.handleSettleUpTap(payerId: hasDue ? id : memberId,
                                                                receiverId: hasDue ? memberId : id,
                                                                amount: amount, currency: currency)
                                }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareReminderSheet) {
            if let reminderText {
                ShareSheetView(activityItems: [reminderText]) { isCompleted in
                    if isCompleted {
                        showShareReminderSheet = false
                    }
                }
            }
        }
    }

    private func generateReminderText(owedMemberName: String, owesText: String, amount: Double,
                                      currency: String, owesMemberName: String) -> String {
        let formattedAmount = amount.formattedCurrency(currency)
        let groupName = viewModel.group?.name ?? ""
        let deepLink = "\(Constants.groupBaseUrl)\(viewModel.groupId)"

        if owesText == "owe" {
            return "Hello \(owesMemberName), This is a reminder that I owe you \(formattedAmount) for expenses in the Splito group \"\(groupName)\". Please follow this link to review our activity: \(deepLink)"
        } else if owesText == "owes" {
            return "Hello \(owedMemberName), This is a reminder that you owe me \(formattedAmount) for expenses in the Splito group \"\(groupName)\". Please follow this link to review our activity and settle up: \(deepLink)"
        } else {
            return "This is a reminder that \(owedMemberName) owes \(owesMemberName) \(formattedAmount) for expenses in the Splito group \"\(groupName)\". Please follow this link to review your activity and settle up: \(deepLink)"
        }
    }
}

private struct RemindAndSettleBtnView: View {
    let SUB_IMAGE_HEIGHT: CGFloat = 24

    let handleRemindTap: () -> Void
    let handleSettleUpTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HSpacer(SUB_IMAGE_HEIGHT)

            balancesButton(title: "Remind", onClick: handleRemindTap)
            balancesButton(title: "Settle up", onClick: handleSettleUpTap)
        }
    }

    func balancesButton(title: String, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            Text(title.localized)
                .font(.caption1())
                .foregroundStyle(primaryText)
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
                .background(container2Color)
                .cornerRadius(30)
        }
    }
}
