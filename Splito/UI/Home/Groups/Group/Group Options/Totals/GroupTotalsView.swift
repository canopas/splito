//
//  GroupTotalsView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle

struct GroupTotalsView: View {

    @StateObject var viewModel: GroupTotalsViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VSpacer(12)

                        GroupTotalTabView(selectedTab: viewModel.selectedTab,
                                          onSelect: viewModel.handleTabItemSelection(_:))

                        GroupTotalSummaryView(viewModel: viewModel)
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Group spending summary")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

private struct GroupTotalTabView: View {

    let selectedTab: GroupTotalsTabType
    let onSelect: ((GroupTotalsTabType) -> Void)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GroupTotalsTabType.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.tabItem.localized)
                        .font(.buttonText())
                        .foregroundColor(selectedTab == tab ? inversePrimaryText : disableText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .lineLimit(1)
                        .background(selectedTab == tab ? primaryDarkColor : container2Color)
                        .cornerRadius(30)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .transaction { transaction in
            transaction.animation = nil
        }
        .padding(.horizontal, 16)
    }
}

private struct GroupTotalSummaryView: View {

    @ObservedObject var viewModel: GroupTotalsViewModel

    private var totalGroupSpending: Double {
        return viewModel.filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var totalPaid: Double {
        return viewModel.getTotalPaid()
    }

    private var totalShare: Double {
        return viewModel.getTotalShareAmount()
    }

    private var paymentsMade: Double {
        return viewModel.getPaymentsMade()
    }

    private var paymentsReceived: Double {
        return viewModel.getPaymentsReceived()
    }

    private var totalChangeInBalance: Double {
        return viewModel.getTotalChangeInBalance()
    }

    var body: some View {
        VStack(spacing: 0) {
            GroupSummaryAmountView(text: "Total group spending", amount: totalGroupSpending)
            GroupSummaryAmountView(text: "Total you paid for", amount: totalPaid)
            GroupSummaryAmountView(text: "Your total share", amount: totalShare, fontColor: alertColor)
            GroupSummaryAmountView(text: "Payments made", amount: paymentsMade, fontColor: alertColor)
            GroupSummaryAmountView(text: "Payments received", amount: paymentsReceived)
            GroupSummaryAmountView(text: "Total change in balance", amount: totalChangeInBalance,
                                   fontColor: (totalChangeInBalance < 0 ? alertColor : successColor), isLast: true)
        }
    }
}

private struct GroupSummaryAmountView: View {

    let text: String
    let amount: Double
    var fontColor: Color
    var isLast: Bool

    init(text: String, amount: Double, fontColor: Color = successColor, isLast: Bool = false) {
        self.text = text
        self.amount = amount
        self.fontColor = fontColor
        self.isLast = isLast
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(text.localized)
                .font(.subTitle2())
                .foregroundColor(primaryText)

            Spacer()

            Text((amount < 0 ? "-" : "") + amount.formattedCurrency)
                .font(.body1())
                .foregroundColor(amount == 0 ? lowestText : fontColor)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)

        if !isLast {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }
}

#Preview {
    GroupTotalsView(viewModel: GroupTotalsViewModel(groupId: ""))
}
