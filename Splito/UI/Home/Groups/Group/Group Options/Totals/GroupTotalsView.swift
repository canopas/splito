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

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(viewModel.group?.name ?? "")
                            .font(.body1(26))
                            .foregroundStyle(primaryText)
                            .padding(.vertical, 10)
                            .padding(.top, 20)

                        GroupTotalTabView(selectedTab: viewModel.selectedTab,
                                          onSelect: viewModel.handleTabItemSelection(_:))

                        GroupTotalSummaryView(viewModel: viewModel)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Group spending summary", displayMode: .inline)
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

private struct GroupTotalTabView: View {

    let selectedTab: GroupTotalsTabType
    let onSelect: ((GroupTotalsTabType) -> Void)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GroupTotalsTabType.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.tabItem.localized)
                        .font(.body2())
                        .foregroundColor(selectedTab == tab ? surfaceDarkColor : primaryText)
                        .padding(.vertical, 8)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(selectedTab == tab ? surfaceLightColor : Color.clear)
                        .cornerRadius(selectedTab == tab ? 8 : 0)
                        .padding(.all, 2)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .background(containerNormalColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .center)
        .transaction { transaction in
            transaction.animation = nil
        }
        .padding(.bottom, 10)
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

    private var totalChangeInBalance: Double {
        return viewModel.getTotalChangeInBalance()
    }

    private var paymentsMade: Double {
        return viewModel.getPaymentsMade()
    }

    private var paymentsReceived: Double {
        return viewModel.getPaymentsReceived()
    }

    var body: some View {
        VStack(spacing: 20) {
            GroupSummaryAmountView(text: "Total group spending", amount: totalGroupSpending, fontColor: amountLentColor)
            GroupSummaryAmountView(text: "Total you paid for", amount: totalPaid, fontColor: amountLentColor)
            GroupSummaryAmountView(text: "Your total share", amount: totalShare, fontColor: amountBorrowedColor)
            GroupSummaryAmountView(text: "Payments made", amount: paymentsMade)
            GroupSummaryAmountView(text: "Payments received", amount: paymentsReceived)
            GroupSummaryAmountView(text: "Total change in balance", amount: totalChangeInBalance,
                                   fontColor: (totalChangeInBalance < 0 ? amountBorrowedColor : amountLentColor))
        }
        .padding(.horizontal, 4)
    }
}

private struct GroupSummaryAmountView: View {

    let text: String
    let amount: Double
    var fontColor: Color

    init(text: String, amount: Double, fontColor: Color = primaryText) {
        self.text = text
        self.amount = amount
        self.fontColor = fontColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text.localized)
                .font(.body1())
                .foregroundColor(primaryText)

            Spacer()

            Text((amount < 0 ? "-" : "") + amount.formattedCurrency)
                .font(.body1())
                .foregroundColor(amount == 0 ? secondaryText : fontColor)
        }
    }
}

#Preview {
    GroupTotalsView(viewModel: GroupTotalsViewModel(groupId: ""))
}
