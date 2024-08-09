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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if case .loading = viewModel.viewState {
                    LoaderView()
                } else {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            TransactionInfoView(geometry: geometry, viewModel: viewModel)
                                .padding(.top, 16)

                            Text("This payment was noted using the \"record a payment\" feature, No money has been transferred.")
                                .font(.caption1())
                                .foregroundStyle(disableText)
                                .multilineTextAlignment(.center)
                                .padding(.top, 24)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
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
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Transaction detail")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(imageIcon: .binIcon, onClick: viewModel.handleDeleteBtnAction)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(imageIcon: .editPencilIcon, onClick: viewModel.handleEditBtnAction)
            }
        }
        .onAppear(perform: viewModel.fetchTransaction)
    }
}

private struct TransactionInfoView: View {

    @Inject var preference: SplitoPreference

    let geometry: GeometryProxy
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

    var payerImageUrl: String {
        let user = viewModel.getMemberDataBy(id: viewModel.transaction?.payerId ?? "")
        return user?.imageUrl ?? ""
    }

    var receiverImageUrl: String {
        let user = viewModel.getMemberDataBy(id: viewModel.transaction?.receiverId ?? "")
        return user?.imageUrl ?? ""
    }

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            HStack(spacing: 24) {
                ProfileCardView(name: payerName, imageUrl: payerImageUrl, geometry: geometry)

                Image(.transactionIcon)
                    .resizable()
                    .frame(width: 35, height: 36)
                    .padding(7)

                ProfileCardView(name: receiverName, imageUrl: receiverImageUrl, geometry: geometry)
            }
            .padding(16)

            TransactionSummaryView(date: viewModel.transaction?.date.dateValue(), amount: viewModel.transaction?.amount, payerName: payerName, receiverName: receiverName, addedUserName: addedUserName)
        }
        .multilineTextAlignment(.center)
    }
}

struct ProfileCardView: View {

    let name: String
    let imageUrl: String?
    let geometry: GeometryProxy

    private var width: CGFloat {
        (isIpad ? (geometry.size.width > 600 ? 600 : geometry.size.width) : geometry.size.width)
    }

    var body: some View {
        VStack(spacing: 8) {
            MemberProfileImageView(imageUrl: imageUrl)

            Text("\(name.localized.capitalized)")
                .font(.body2())
                .foregroundStyle(primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(width: width * 0.3, height: 97)
        .background(container2Color)
        .cornerRadius(12)
    }
}

private struct TransactionSummaryView: View {

    let date: Date?
    let amount: Double?
    let payerName: String
    let receiverName: String
    let addedUserName: String

    var body: some View {
        VStack(spacing: 0) {
            Text("\(payerName.localized) paid \(receiverName.localized)")
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .lineSpacing(2)
                .padding(.bottom, 8)

            Text(amount?.formattedCurrency ?? "₹ 0")
                .font(.Header2())
                .foregroundStyle(primaryText)

            Divider()
                .frame(height: 1)
                .background(dividerColor)
                .padding(.vertical, 16)

            Text("Added by \(addedUserName.localized) on \(date?.longDate ?? "Today")")
                .font(.body3())
                .foregroundStyle(secondaryText)
                .tracking(0.5)
        }
        .padding(16)
        .background(containerColor)
        .cornerRadius(12)
    }
}

#Preview {
    GroupTransactionDetailView(viewModel: GroupTransactionDetailViewModel(router: .init(root: .TransactionDetailView(transactionId: "", groupId: "")), groupId: "", transactionId: ""))
}
