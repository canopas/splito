//
//  ChooseMultiplePayerView.swift
//  Splito
//
//  Created by Amisha Italiya on 08/07/24.
//

import Data
import SwiftUI
import BaseStyle

struct ChooseMultiplePayerView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: ChooseMultiplePayerViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            NavigationBarTopView(title: "Multiple people",
                leadingButton: {
                    BackButton(size: (10, 16), iconColor: primaryText, padding: (22, 0), onClick: {
                        dismiss()
                    })
                    .fontWeight(.medium)
                }(),
                trailingButton: CheckmarkButton(padding: (.horizontal, 16), onClick: viewModel.handleDoneBtnTap)
            )

            Spacer(minLength: 0)

            if .noInternet == viewModel.currentViewState || .somethingWentWrong == viewModel.currentViewState {
                ErrorView(isForNoInternet: viewModel.currentViewState == .noInternet, onClick: viewModel.fetchInitialViewData)
            } else if case .loading = viewModel.currentViewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        VSpacer(27)

                        EnterPaidAmountsView(viewModel: viewModel)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                let currency = viewModel.amountCurrency
                BottomInfoCardView(title: "\(viewModel.totalAmount.formattedCurrency(currency)) of \(viewModel.expenseAmount.formattedCurrency(currency))",
                                   value: "\((viewModel.expenseAmount - viewModel.totalAmount).formattedCurrency(currency)) left")
            }
        }
        .background(surfaceColor)
        .interactiveDismissDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct EnterPaidAmountsView: View {

    @ObservedObject var viewModel: ChooseMultiplePayerViewModel

    var body: some View {
        VStack(spacing: 16) {
            let currencySymbol = Currency.getCurrencyFromCode(viewModel.amountCurrency).symbol
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.membersAmount[member.id] ?? 0 },
                        set: { viewModel.updateAmount(for: member.id, amount: $0) }
                    ),
                    member: member, suffixText: currencySymbol,
                    formatString: "%.2f",
                    isLastCell: member == viewModel.groupMembers.last,
                    expenseAmount: viewModel.totalAmount, amountCurrency: viewModel.amountCurrency,
                    inputFieldWidth: 70,
                    onChange: { amount in
                        viewModel.updateAmount(for: member.id, amount: amount)
                    }
                )
            }
        }
    }
}
