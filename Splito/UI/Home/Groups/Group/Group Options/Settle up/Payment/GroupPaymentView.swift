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
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                if case .loading = viewModel.viewState {
                    LoaderView()
                } else {
                    VStack(alignment: .center, spacing: 20) {
                        VSpacer(80)

                        HStack(alignment: .center, spacing: 20) {
                            MemberProfileImageView(imageUrl: viewModel.payer?.imageUrl, height: 80)

                            Image(systemName: "arrowshape.forward.fill")
                                .resizable()
                                .frame(width: 36, height: 18)
                                .foregroundStyle(primaryText.opacity(0.6))

                            MemberProfileImageView(imageUrl: viewModel.receiver?.imageUrl, height: 80)
                        }
                        .padding(.top, 20)

                        Text("\(viewModel.payerName.localized) paid \(viewModel.payableName.localized)")
                            .font(.body1())
                            .foregroundStyle(primaryText)

                        HStack(alignment: .center) {
                            Text("Date:")
                                .font(.subTitle2())
                                .foregroundStyle(primaryText)

                            DatePicker("", selection: $viewModel.paymentDate, in: ...viewModel.maximumDate, displayedComponents: .date)
                                .labelsHidden()
                                .onTapGesture(count: 99) {}
                        }
                        .padding(.top, 16)

                        GroupPaymentAmountView(amount: $viewModel.amount)

                        VSpacer(20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(backgroundColor)
            .toastView(toast: $viewModel.toast)
            .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
            .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
            .navigationBarTitle(viewModel.transactionId != nil ? "Edit payment" : "Record a payment", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: viewModel.handleSaveAction)
                }
                if viewModel.transactionId != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: viewModel.dismissPaymentFlow)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct GroupPaymentAmountView: View {

    @Binding var amount: Double
    @FocusState var isAmountFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "indianrupeesign.square")
                .resizable()
                .frame(width: 30, height: 30)
                .padding(.top, 5)

            TextField("0.00", value: $amount, formatter: numberFormatter)
                .keyboardType(.decimalPad)
                .frame(width: 140)
                .font(.Header1(30))
                .focused($isAmountFocused)
                .overlay(
                    VStack(spacing: 40) {
                        Spacer()
                        Rectangle()
                            .frame(height: 2)
                            .foregroundStyle(primaryColor)
                    }
                )
        }
        .padding(.vertical, 10)
        .foregroundStyle(primaryText)
        .onAppear {
            isAmountFocused = true
        }
    }
}
