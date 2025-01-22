//
//  GroupTotalsView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupTotalsView: View {

    @StateObject var viewModel: GroupTotalsViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialGroupData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 0) {
                            if let groupName = viewModel.group?.name {
                                Text(groupName)
                                    .font(.Header4())
                                    .foregroundStyle(primaryText)
                            }

                            Spacer()

                            CapsuleButton(buttonName: viewModel.selectedCurrency.code, paddingHr: 16, paddingVr: 6,
                                          cornerRadius: 23, onClick: viewModel.handleSelectedCurrencyTap)
                        }
                        .padding([.horizontal, .top], 16)

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
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Group spending summary")
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCurrencyPicker) {
            NavigationStack {
                CurrencyPickerView(selectedCurrency: $viewModel.selectedCurrency, isPresented: $viewModel.showCurrencyPicker,
                                   supportedCurrencies: viewModel.supportedCurrencies)
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
                let currencyCode = viewModel.selectedCurrency.code

                GroupSummaryAmountView(text: "Total group spending", amount: summaryData.groupTotalSpending,
                                       currencyCode: currencyCode)
                GroupSummaryAmountView(text: "Total you paid for", amount: summaryData.totalPaidAmount,
                                       currencyCode: currencyCode)
                GroupSummaryAmountView(text: "Your total share", amount: summaryData.totalShare,
                                       currencyCode: currencyCode, fontColor: errorColor)
                GroupSummaryAmountView(text: "Payments made", amount: summaryData.paidAmount,
                                       currencyCode: currencyCode)
                GroupSummaryAmountView(text: "Payments received", amount: summaryData.receivedAmount,
                                       currencyCode: currencyCode, fontColor: errorColor)
                GroupSummaryAmountView(text: "Total change in balance", amount: summaryData.changeInBalance, currencyCode: currencyCode,
                                       fontColor: (summaryData.changeInBalance < 0 ? errorColor : successColor), isLast: true)
            }
        }
    }
}

private struct GroupSummaryAmountView: View {

    let text: String
    let amount: Double
    let currencyCode: String
    let fontColor: Color
    let isLast: Bool

    init(text: String, amount: Double, currencyCode: String, fontColor: Color = successColor, isLast: Bool = false) {
        self.text = text
        self.amount = amount
        self.currencyCode = currencyCode
        self.fontColor = fontColor
        self.isLast = isLast
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(text.localized)
                .font(.subTitle2())
                .foregroundStyle(primaryText)

            Spacer()

            Text(amount.formattedCurrency(currencyCode, true))
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
