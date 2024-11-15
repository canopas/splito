//
//  GroupPaymentView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupPaymentView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: GroupPaymentViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                    ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialViewData)
                } else if case .loading = viewModel.viewState {
                    LoaderView()
                } else {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            VSpacer(27)

                            PayerReceiverProfileView(geometry: geometry, payerName: viewModel.payerName, payableName: viewModel.payableName,
                                                     payerImageUrl: viewModel.payer?.imageUrl, receiverImageUrl: viewModel.receiver?.imageUrl)

                            VSpacer(16)

                            AmountRowView(amount: $viewModel.amount, subtitle: "Enter amount")

                            VSpacer(16)

                            PaymentDateRowView(date: $viewModel.paymentDate)

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)

                    PrimaryButton(text: "Done", showLoader: viewModel.showLoader, onClick: {
                        Task {
                            let isSucceed = await viewModel.handleSaveAction()
                            if isSucceed {
                                dismiss()
                            } else {
                                viewModel.showSaveFailedError()
                            }
                        }
                    })
                    .padding([.horizontal, .bottom], 16)
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: viewModel.transactionId != nil ? "Edit payment" : "Record a payment")
            }
        }
    }
}

private struct PayerReceiverProfileView: View {

    let geometry: GeometryProxy
    let payerName: String
    let payableName: String
    let payerImageUrl: String?
    let receiverImageUrl: String?

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                ProfileCardView(name: payerName, imageUrl: payerImageUrl, geometry: geometry)

                Image(.transactionIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)

                ProfileCardView(name: payableName, imageUrl: receiverImageUrl, geometry: geometry)
            }

            Divider()
                .frame(height: 1)
                .background(dividerColor)

            Text("\(payerName.localized) paid \(payableName.localized)")
                .font(.body3())
                .foregroundStyle(disableText)
                .tracking(0.5)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(container2Color)
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct AmountRowView: View {

    @Binding var amount: Double

    let subtitle: String

    @FocusState var isAmountFocused: Bool
    @State private var amountString: String = ""

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Text(subtitle.localized)
                .font(.subTitle1())
                .foregroundStyle(primaryText)
                .tracking(-0.2)

            TextField("0.00", text: $amountString)
                .keyboardType(.decimalPad)
                .font(.Header1())
                .tint(primaryColor)
                .foregroundStyle(primaryText)
                .focused($isAmountFocused)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .onChange(of: amountString) { newValue in
                    if let value = Double(newValue) {
                        amount = value
                    } else {
                        amount = 0
                    }
                }
                .onAppear {
                    amountString = amount == 0 ? "" : String(format: "%.2f", amount)
                }
        }
        .padding(24)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1)
        }
        .onAppear {
            isAmountFocused = true
        }
    }
}

private struct PaymentDateRowView: View {

    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.body3())
                .foregroundStyle(disableText)

            DatePickerRow(date: $date)
                .padding(16)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(outlineColor, lineWidth: 1)
                }
        }
    }
}
