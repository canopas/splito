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

    @Inject private var preference: SplitoPreference
    @StateObject var viewModel: GroupPaymentViewModel

    var payerName: String {
        if let user = preference.user, user.id == viewModel.payerId {
            return "You"
        }
        return viewModel.payer?.nameWithLastInitial ?? "Unknown"
    }

    var payableName: String {
        if let user = preference.user, user.id == viewModel.receiverId {
            return "You"
        }
        return viewModel.receiver?.nameWithLastInitial ?? "Unknown"
    }

    let maximumDate = Calendar.current.date(byAdding: .year, value: 0, to: Date())!

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
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

                        Text("\(payerName) paid \(payableName)")
                            .font(.body1())
                            .foregroundStyle(primaryText)

                        DatePicker("Date:", selection: $viewModel.paymentDate,
                                   in: ...maximumDate, displayedComponents: .date)
                        .font(.subTitle2())
                        .padding(.top, 16)
                        .frame(width: 170, alignment: .center)

                        GroupPaymentAmountView(amount: $viewModel.amount)

                        VSpacer(20)
                    }
                }
                .padding(.horizontal, 20)
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Record a payment", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    viewModel.handleSaveAction {

                    }
                }
                .foregroundStyle(primaryColor)
            }
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

            TextField("0.00", value: $amount, formatter: NumberFormatter())
                .keyboardType(.numberPad)
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
