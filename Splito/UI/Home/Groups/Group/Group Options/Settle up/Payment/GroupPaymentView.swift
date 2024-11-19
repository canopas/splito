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
                            VSpacer(16)

                            VStack(alignment: .center, spacing: 24) {
                                HStack(alignment: .center, spacing: 24) {
                                    ProfileCardView(name: viewModel.payerName, imageUrl: viewModel.payer?.imageUrl, geometry: geometry)

                                    Image(.transactionIcon)
                                        .resizable()
                                        .frame(width: 35, height: 36)
                                        .padding(7)

                                    ProfileCardView(name: viewModel.payableName, imageUrl: viewModel.receiver?.imageUrl, geometry: geometry)
                                }

                                Text("\(viewModel.payerName.localized) paid \(viewModel.payableName.localized)")
                                    .font(.body3())
                                    .foregroundStyle(disableText)
                                    .tracking(0.5)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                            .background(container2Color)
                            .cornerRadius(16)

                            VSpacer(16)

                            AmountRowView(amount: $viewModel.amount, subtitle: "Enter amount")

                            VSpacer(16)

                            PaymentDateRow(date: $viewModel.paymentDate, subtitle: "Date")

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

private struct PaymentDateRow: View {

    @Binding var date: Date

    let subtitle: String

    @State private var showDatePicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            DatePickerRow(date: $date)
                .padding(16)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                }
        }
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

            TextField(" ₹ 0.00", text: $amountString)
                .keyboardType(.decimalPad)
                .font(.Header1())
                .tint(primaryColor)
                .foregroundStyle(primaryText)
                .focused($isAmountFocused)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .onChange(of: amountString) { newValue in
                    formatAmount(newValue: newValue)
                }
                .onAppear {
                    amountString = amount == 0 ? "" : String(format: "₹ %.2f", amount)
                    isAmountFocused = true
                }
        }
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1)
        }
    }

    private func formatAmount(newValue: String) {
        // Remove the "₹" symbol and whitespace to process the numeric value
        let numericInput = newValue.replacingOccurrences(of: "₹", with: "").trimmingCharacters(in: .whitespaces)
        if let value = Double(numericInput) {
            amount = value
        } else {
            amount = 0
        }

        // Update amountString to include "₹" prefix
        amountString = numericInput.isEmpty ? "" : "₹ " + numericInput
    }
}
