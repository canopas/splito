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

    @State private var showImageDisplayView = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                    ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialTransactionData)
                } else if case .loading = viewModel.viewState {
                    LoaderView()
                } else {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            VSpacer(16)

                            TransactionInfoView(geometry: geometry, viewModel: viewModel)

                            Text("This payment was noted using the \"record a payment\" feature, No money has been transferred.")
                                .font(.caption1())
                                .foregroundStyle(disableText)
                                .multilineTextAlignment(.center)
                                .padding(.top, 24)

                            if let imageUrl = viewModel.transaction?.imageUrl, !imageUrl.isEmpty {
                                VStack(spacing: 8) {
                                    Text("Attachment:")
                                        .font(.subTitle3())
                                        .foregroundStyle(disableText)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    AttachmentContainerView(showImageDisplayView: $showImageDisplayView, imageUrl: imageUrl)
                                        .frame(height: 140)
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(12)
                                }
                                .padding(.top, 16)
                            }

                            if let note = viewModel.transaction?.note, !note.isEmpty {
                                NoteContainerView(note: note, handleNoteTap: viewModel.handleNoteTap)
                                    .padding(.top, 16)
                            }

                            VSpacer(24)
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
                        amount: viewModel.transaction?.amount ?? 0
                    )
                )
            }
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Payment detail")
            }
            if viewModel.viewState != .loading {
                if (viewModel.transaction?.isActive ?? false) && (viewModel.group?.isActive ?? false) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ToolbarButtonView(imageIcon: .binIcon, onClick: viewModel.handleDeleteBtnAction)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ToolbarButtonView(imageIcon: .editPencilIcon, onClick: viewModel.handleEditBtnAction)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        RestoreButton(onClick: viewModel.handleRestoreButtonAction)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAddNoteEditor) {
            NavigationStack {
                AddNoteView(viewModel: AddNoteViewModel(group: viewModel.group, payment: viewModel.transaction, note: viewModel.paymentNote))
            }
        }
        .navigationDestination(isPresented: $showImageDisplayView) {
            if let imageUrl = viewModel.transaction?.imageUrl, !imageUrl.isEmpty {
                AttachmentZoomView(imageUrl: imageUrl)
            }
        }
    }
}

@MainActor
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
                    .scaledToFit()
                    .frame(width: 42, height: 42)

                ProfileCardView(name: receiverName, imageUrl: receiverImageUrl, geometry: geometry)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(container2Color)
            .cornerRadius(16)

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
        .frame(width: width * 0.3, height: 87)
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
