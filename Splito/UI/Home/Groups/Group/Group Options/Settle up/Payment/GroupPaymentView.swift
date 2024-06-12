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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                VStack(alignment: .center, spacing: 20) {
                    HStack(alignment: .center, spacing: 20) {
                        MemberProfileImageView(imageUrl: viewModel.payer?.imageUrl, height: 80)

                        Image(systemName: "arrowshape.forward.fill")
                            .resizable()
                            .frame(width: 36, height: 18)
                            .foregroundStyle(primaryText.opacity(0.6))

                        MemberProfileImageView(imageUrl: viewModel.receiver?.imageUrl, height: 80)
                    }

                    Text("\(payerName) paid \(payableName)")
                        .font(.body1())
                        .foregroundStyle(primaryText)

                    GroupPaymentAmountView(amount: $viewModel.amount)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
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
        VStack(alignment: .center) {
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
        .onAppear {
            isAmountFocused = true
        }
    }
}
