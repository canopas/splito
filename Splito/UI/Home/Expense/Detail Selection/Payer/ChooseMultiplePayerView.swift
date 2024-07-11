//
//  ChooseMultiplePayerView.swift
//  Splito
//
//  Created by Amisha Italiya on 08/07/24.
//

import SwiftUI
import BaseStyle

struct ChooseMultiplePayerView: View {

    @StateObject var viewModel: ChooseMultiplePayerViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.4))

            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else {
                ZStack {
                    ScrollView {
                        VStack(spacing: 50) {
                            Divider()
                                .frame(height: 1)
                                .background(outlineColor.opacity(0.4))

                            EnterPaidAmountsView(viewModel: viewModel)

                            VSpacer(80)
                        }
                    }
                    .scrollIndicators(.hidden)

                    BottomInfoCardView(title: "₹ \(String(format: "%.2f", viewModel.totalAmount)) of ₹ \(viewModel.expenseAmount)",
                                       value: "₹ \(String(format: "%.2f", (viewModel.expenseAmount - viewModel.totalAmount))) left")
                }
            }
        }
        .background(backgroundColor)
        .interactiveDismissDisabled()
        .navigationBarTitle("Choose Payer", displayMode: .inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    viewModel.handleDoneBtnTap()
                }
            }
        }
    }
}

private struct EnterPaidAmountsView: View {

    @ObservedObject var viewModel: ChooseMultiplePayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.membersAmount[member.id] ?? 0 },
                        set: { viewModel.updateAmount(for: member.id, amount: $0) }
                    ),
                    member: member, suffixText: "₹",
                    formatString: "%.2f",
                    expenseAmount: viewModel.totalAmount,
                    inputFieldWidth: 80,
                    onChange: { amount in
                        viewModel.updateAmount(for: member.id, amount: amount)
                    }
                )
            }
        }
    }
}

#Preview {
    ChooseMultiplePayerView(viewModel: ChooseMultiplePayerViewModel(groupId: "", expenseAmount: 0, onPayerSelection: {_ in }, dismissChoosePayerFlow: {}))
}
