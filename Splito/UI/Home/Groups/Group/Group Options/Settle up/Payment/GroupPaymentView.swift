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

    @StateObject var viewModel: GroupPaymentViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .center, spacing: 0) {
                        if case .loading = viewModel.viewState {
                            LoaderView()
                        } else {
                            VStack(alignment: .center, spacing: 0) {
                                VSpacer(27)

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

                                VSpacer(40)

                                PaymentDetailRow(amount: $viewModel.amount, date: $viewModel.paymentDate, subtitle: "Date", placeholder: "Enter payment date", maximumDate: viewModel.maximumDate, forDatePicker: true)

                                VSpacer(16)

                                PaymentDetailRow(amount: $viewModel.amount, date: $viewModel.paymentDate, subtitle: "Enter amount", placeholder: "0.00", maximumDate: viewModel.maximumDate)

                                Spacer(minLength: 40)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PrimaryButton(text: "Done", showLoader: viewModel.showLoader, onClick: viewModel.handleSaveAction)
                    .padding([.horizontal, .bottom], 16)
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(viewModel.transactionId != nil ? "Edit payment" : "Record a payment")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

private struct PaymentDetailRow: View {

    @Binding var amount: Double
    @Binding var date: Date

    let subtitle: String
    let placeholder: String
    var maximumDate: Date
    var forDatePicker: Bool = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }

    @FocusState var isAmountFocused: Bool
    @State private var showDatePicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            VStack(alignment: .leading, spacing: 0) {
                if forDatePicker {
                    Text(dateFormatter.string(from: date))
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)
                        .overlay {
                            DatePicker("", selection: $date, in: ...maximumDate, displayedComponents: .date)
                                .blendMode(.destinationOver)
                                .onTapGesture(count: 99) {}
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("0.00", value: $amount, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)
                        .focused($isAmountFocused)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outlineColor, lineWidth: 1)
            }
            .onAppear {
                isAmountFocused = true
            }
        }
    }
}
