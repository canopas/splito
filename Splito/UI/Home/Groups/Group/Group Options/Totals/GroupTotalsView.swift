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
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.onViewAppear)
            } else if case .loading = viewModel.viewState {
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

    let selectedTab: DateRangeTabType
    let onSelect: ((DateRangeTabType) -> Void)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DateRangeTabType.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.tabItem.localized)
                        .font(.buttonText())
                        .foregroundStyle(selectedTab == tab ? inversePrimaryText : disableText)
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

    var body: some View {
        VStack(spacing: 0) {
            if let summaryData = viewModel.summaryData {
                GroupSummaryAmountView(text: "Total group spending", amount: summaryData.groupTotalSpending)
                GroupSummaryAmountView(text: "Total you paid for", amount: summaryData.totalPaidAmount)
                GroupSummaryAmountView(text: "Your total share", amount: summaryData.totalShare, fontColor: alertColor)
                GroupSummaryAmountView(text: "Payments made", amount: summaryData.paidAmount)
                GroupSummaryAmountView(text: "Payments received", amount: summaryData.receivedAmount, fontColor: alertColor)
                GroupSummaryAmountView(text: "Total change in balance", amount: summaryData.changeInBalance,
                                       fontColor: (summaryData.changeInBalance < 0 ? alertColor : successColor), isLast: true)
            }
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
                .foregroundStyle(primaryText)

            Spacer()

            Text((amount < 0 ? "-" : "") + amount.formattedCurrency)
                .font(.body1())
                .foregroundStyle(amount == 0 ? lowestText : fontColor)
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
