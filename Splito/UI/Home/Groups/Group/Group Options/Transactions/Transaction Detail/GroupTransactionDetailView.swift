//
//  GroupTransactionDetailView.swift
//  Splito
//
//  Created by Amisha Italiya on 17/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupTransactionDetailView: View {

    @StateObject var viewModel: GroupTransactionDetailViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .center, spacing: 30) {
                        VSpacer(24)

                        TransactionInfoView(viewModel: viewModel)

                        Divider()
                            .frame(height: 1)
                            .background(outlineColor)

                        Text("This payment was added using the \"record a payment\" feature. No money has been moved.")
                            .font(.body2())
                            .lineSpacing(2)
                            .foregroundStyle(disableText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        VSpacer()
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Details", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .fullScreenCover(isPresented: $viewModel.showEditTransactionSheet) {
            NavigationStack {
                GroupPaymentView(
                    viewModel: GroupPaymentViewModel(
                        router: viewModel.router, transactionId: viewModel.transactionId,
                        groupId: viewModel.groupId, payerId: viewModel.transaction?.payerId ?? "",
                        receiverId: viewModel.transaction?.receiverId ?? "",
                        amount: viewModel.transaction?.amount ?? 0,
                        dismissPaymentFlow: viewModel.dismissEditTransactionSheet
                    )
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.handleDeleteBtnAction) {
                    Image(systemName: "trash")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.handleEditBtnAction) {
                    Image(systemName: "pencil")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
        }
        .onAppear(perform: viewModel.fetchTransaction)
    }
}

private struct TransactionInfoView: View {

    @Inject var preference: SplitoPreference

    let viewModel: GroupTransactionDetailViewModel

    var addedUserName: String {
        let user = viewModel.getMemberDataBy(id: viewModel.transaction?.addedBy ?? "")
        return preference.user?.id == user?.id ? "you" : user?.nameWithLastInitial ?? "someone"
    }

    var payerName: String {
        let user = viewModel.getMemberDataBy(id: viewModel.transaction?.payerId ?? "")
        return preference.user?.id == user?.id ? "You" : user?.nameWithLastInitial ?? "Someone"
    }

    var receiverName: String {
        let user = viewModel.getMemberDataBy(id: viewModel.transaction?.receiverId ?? "")
        return preference.user?.id == user?.id ? "you" : user?.nameWithLastInitial ?? "someone"
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 60)
                .padding(10)

            Text("\(payerName.localized) paid \(receiverName.localized)")
                .font(.body1(22))
                .foregroundStyle(primaryText)

            Text(viewModel.transaction?.amount.formattedCurrency ?? "₹ 0")
                .font(.H1Text(36))
                .foregroundStyle(primaryText)

            Text("Added by \(addedUserName.localized) on \(viewModel.transaction?.date.dateValue().longDate ?? "Today")")
                .lineLimit(0)
                .font(.body1())
                .foregroundStyle(secondaryText)
                .padding(.top, 8)
        }
        .padding(.horizontal, 30)
    }
}

#Preview {
    GroupTransactionDetailView(viewModel: GroupTransactionDetailViewModel(router: .init(root: .TransactionDetailView(transactionId: "", groupId: "")), groupId: "", transactionId: ""))
}
