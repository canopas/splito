//
//  ExpenseDetailsView.swift
//  Splito
//
//  Created by Amisha Italiya on 17/04/24.
//

import SwiftUI
import BaseStyle
import Data

struct ExpenseDetailsView: View {

    @StateObject var viewModel: ExpenseDetailsViewModel

    @State private var showImageDisplayView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchGroupAndExpenseData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ExpenseHeaderView(viewModel: viewModel)

                        ExpenseInfoView(viewModel: viewModel)

                        if let imageUrl = viewModel.expense?.imageUrl {
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
                            .padding(.top, 4)
                        }

                        if let note = viewModel.expense?.note, !note.isEmpty {
                            NoteContainerView(note: note, handleNoteTap: viewModel.handleNoteTap)
                                .padding(.top, 16)
                        }

                        VSpacer(24)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .fullScreenCover(isPresented: $viewModel.showEditExpenseSheet) {
            NavigationStack {
                AddExpenseView(viewModel: AddExpenseViewModel(router: viewModel.router, groupId: viewModel.groupId, expenseId: viewModel.expenseId))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAddNoteEditor) {
            NavigationStack {
                AddNoteView(viewModel: AddNoteViewModel(group: viewModel.group, expense: viewModel.expense, note: viewModel.expenseNote))
            }
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Details")
            }
            if viewModel.viewState != .loading {
                if (viewModel.expense?.isActive ?? false) && (viewModel.group?.isActive ?? false) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ToolbarButtonView(imageIcon: .binIcon, onClick: viewModel.handleDeleteButtonAction)
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
        .navigationDestination(isPresented: $showImageDisplayView) {
            if let imageUrl = viewModel.expense?.imageUrl, !imageUrl.isEmpty {
                AttachmentZoomView(imageUrl: imageUrl)
            }
        }
    }
}

@MainActor
private struct ExpenseHeaderView: View {

    let viewModel: ExpenseDetailsViewModel

    var username: String {
        let user = viewModel.getMemberDataBy(id: viewModel.expense?.addedBy ?? "")
        return viewModel.preference.user?.id == user?.id ? "you" : user?.nameWithLastInitial ?? "someone"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            GroupProfileImageView(imageUrl: viewModel.groupImageUrl)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.expense?.name ?? "Expense")
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)

                Text(viewModel.expense?.formattedAmount ?? "₹ 0")
                    .font(.Header3())
                    .foregroundStyle(primaryText)

                Text("Added by \(username.localized) on \(viewModel.expense?.date.dateValue().longDate ?? "Today")")
                    .lineLimit(0)
                    .font(.body3())
                    .foregroundStyle(disableText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(container2Color)
        .cornerRadius(12)
        .padding(.top, 24)
    }
}

@MainActor
private struct ExpenseInfoView: View {
    let SUB_IMAGE_HEIGHT: CGFloat = 24

    let viewModel: ExpenseDetailsViewModel

    var expense: Expense? {
        viewModel.expense
    }

    var userName: String {
        if expense?.paidBy.count ?? 0 > 1 {
            if let payerCount = expense?.paidBy.count {
                return "\(String(describing: payerCount)) people"
            }
            return "You"
        } else {
            let user = viewModel.getMemberDataBy(id: expense?.paidBy.first?.key ?? "")
            return viewModel.preference.user?.id == user?.id ? "You" : user?.nameWithLastInitial ?? "someone"
        }
    }

    var userImageUrl: String? {
        return viewModel.getMemberDataBy(id: expense?.paidBy.first?.key ?? "")?.imageUrl
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                MemberProfileImageView(imageUrl: userImageUrl)

                Text("\(userName.localized) paid \(expense?.formattedAmount ?? "nothing")")
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.expenseUsersData, id: \.self) { userData in
                    let owes = viewModel.preference.user?.id == userData.id ? "owe" : "owes"
                    let memberName = viewModel.preference.user?.id == userData.id ? "You" : userData.nameWithLastInitial

                    let paidAmount = expense?.paidBy[userData.id] ?? 0.0
                    let splitAmount = viewModel.getSplitAmount(for: userData.id)

                    HStack(spacing: 16) {
                        if let paidBy = expense?.paidBy, paidBy.contains(where: { $0.key == userData.id }), paidBy.count > 1 {
                            MemberProfileImageView(imageUrl: userData.imageUrl, height: SUB_IMAGE_HEIGHT, scaleEffect: 0.6)

                            if let splitTo = expense?.splitTo, splitTo.contains(userData.id) {
                                Text("\(memberName.localized) paid \(paidAmount.formattedCurrency) and \(owes.localized) \(splitAmount)")
                            } else {
                                Text("\(memberName.localized) paid \(paidAmount.formattedCurrency)")
                            }
                        } else if let splitTo = expense?.splitTo, splitTo.contains(userData.id) {
                            MemberProfileImageView(imageUrl: userData.imageUrl, height: SUB_IMAGE_HEIGHT, scaleEffect: 0.6)

                            Text("\(memberName.localized) \(owes.localized) \(splitAmount)")
                        }
                    }
                    .padding(.leading, 56)

                    if let splitTo = expense?.splitTo, splitTo.contains(userData.id) {
                        VSpacer(16)
                    }
                }
            }
            .font(.body3())
            .foregroundStyle(disableText)
        }
        .padding(.top, 24)
    }
}

struct NoteContainerView: View {

    let note: String

    let handleNoteTap: (() -> Void)

    var body: some View {
        VStack(spacing: 8) {
            Text("Note:")
                .font(.subTitle3())
                .foregroundStyle(disableText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(note)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .lineSpacing(3)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(containerColor)
                .cornerRadius(12)
                .onTapGestureForced(perform: handleNoteTap)
        }
    }
}
