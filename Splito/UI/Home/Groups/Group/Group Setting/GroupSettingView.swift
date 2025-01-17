//
//  GroupSettingView.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct GroupSettingView: View {

    @StateObject var viewModel: GroupSettingViewModel

    var body: some View {
        VStack(spacing: 0) {
            if .noInternet == viewModel.currentViewState || .somethingWentWrong == viewModel.currentViewState {
                ErrorView(isForNoInternet: viewModel.currentViewState == .noInternet, onClick: viewModel.fetchInitialGroupData)
            } else if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .initial = viewModel.currentViewState {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VSpacer(10)

                        GroupTitleView(group: viewModel.group)
                            .onTouchGesture(viewModel.handleEditGroupTap)

                        GroupMembersView(viewModel: viewModel)

                        GroupAdvanceSettingsView(onLeaveGroupTap: viewModel.handleLeaveGroupTap,
                                                 onDeleteGroupTap: viewModel.handleDeleteGroupTap)

                        Spacer(minLength: 40)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Group settings")
            }
        }
        .fullScreenCover(isPresented: $viewModel.showEditGroupSheet) {
            NavigationStack {
                CreateGroupView(viewModel: CreateGroupViewModel(router: viewModel.router, group: viewModel.group))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAddMemberSheet) {
            NavigationStack {
                InviteMemberView(viewModel: InviteMemberViewModel(router: viewModel.router,
                                                                  groupId: viewModel.group?.id ?? ""))
            }
        }
        .onAppear(perform: viewModel.fetchInitialGroupData)
    }
}

private struct GroupTitleView: View {

    let group: Groups?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 0) {
                GroupProfileImageView(imageUrl: group?.imageUrl)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group?.name ?? "")
                        .font(.Header3())
                        .foregroundStyle(primaryText)

                    if let group {
                        Text("\(group.members.count) people")
                            .font(.body3())
                            .foregroundStyle(disableText)
                    }
                }

                Spacer()

                Image(.editPencilIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .fill(container2Color)
            }
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }
}

private struct GroupMembersView: View {

    @ObservedObject var viewModel: GroupSettingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Group Members")
                .font(.Header4())
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)

            VStack(spacing: 20) {
                GroupListEditCellView(icon: .addMemberIcon, text: "Add a new member",
                                      onTap: viewModel.handleAddMemberTap)

                LazyVStack(spacing: 20) {
                    ForEach(viewModel.members) { member in
                        let balance = viewModel.getMembersBalance(memberId: member.id)
                        GroupMemberCellView(member: member, balance: balance,
                                            isAdmin: member.id == viewModel.group?.createdBy)
                        .onTouchGesture {
                            viewModel.handleMemberTap(member: member)
                        }
                    }
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 16)

            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
        .confirmationDialog("", isPresented: $viewModel.showLeaveGroupDialog, titleVisibility: .hidden) {
            Button("Leave Group", action: viewModel.onRemoveAndLeaveFromGroupTap)
        }
        .confirmationDialog("", isPresented: $viewModel.showRemoveMemberDialog, titleVisibility: .hidden) {
            Button("Remove from group", action: viewModel.onRemoveAndLeaveFromGroupTap)
        }
    }
}

private struct GroupListEditCellView: View {

    var icon: ImageResource?
    var text: String
    var fontColor: Color = primaryText

    var showArrowBtn: Bool = false
    var isDestructive: Bool = false

    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if let icon {
                Image(icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .padding(8)
                    .background(container2Color)
                    .cornerRadius(30)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.gray, lineWidth: 1)
                    )
            }

            Text(text.localized)
                .font(.subTitle3())
                .foregroundStyle(fontColor)

            Spacer()

            if showArrowBtn {
                ScrollToTopButton(icon: "chevron.right", iconColor: primaryText,
                                  bgColor: .clear, size: (7, 14), padding: 3, onClick: onTap)
                    .fontWeight(.regular)
            }
        }
        .foregroundStyle(isDestructive ? errorColor : primaryText)
        .onTouchGesture(onTap)
    }
}

private struct GroupMemberCellView: View {

    @Inject var preference: SplitoPreference

    let member: AppUser
    let balance: [String: Double]
    let isAdmin: Bool

    private var userName: String {
        if let user = preference.user, member.id == user.id {
            return "You"
        } else {
            return member.fullName
        }
    }

    private var subInfo: String {
        if let emailId = member.emailId, !emailId.isEmpty {
            return emailId
        } else if let phoneNumber = member.phoneNumber, !phoneNumber.isEmpty {
            return phoneNumber
        } else {
            return "No email address"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(userName.localized)
                        .lineLimit(1)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    if isAdmin {
                        Text(" (Admin)")
                            .font(.caption1())
                            .foregroundStyle(secondaryText)
                    }
                }

                Text(subInfo.localized)
                    .font(.caption1())
                    .foregroundStyle(disableText)
            }

            Spacer()

            if let firstBalance = balance.first {
                let currency = firstBalance.key
                let amount = firstBalance.value
                let isBorrowed = amount < 0
                VStack(alignment: .trailing, spacing: 4) {
                    if amount == 0 {
                        Text("settled up")
                            .font(.caption1())
                            .foregroundStyle(disableText)
                    } else {
                        Text(isBorrowed ? "owes" : "gets back")
                            .font(.caption1())

                        let currencySymbol = Currency.getCurrencyFromCode(currency).symbol
                        Text("\(currencySymbol) \(amount.formattedCurrency)")
                            .font(.body1())
                    }
                }
                .lineLimit(1)
                .foregroundStyle(isBorrowed ? errorColor : successColor)
            }
        }
    }
}

private struct GroupAdvanceSettingsView: View {

    @State var isDebtSimplified = true

    var showSimplifyDebtsToggle: Bool = false

    var onLeaveGroupTap: () -> Void
    var onDeleteGroupTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced Settings")
                .font(.Header4())
                .foregroundStyle(primaryText)

            VStack(spacing: 24) {
                if showSimplifyDebtsToggle {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(isOn: $isDebtSimplified) {
                                Text("Simplify group debts")
                                    .font(.subTitle2())
                                    .foregroundStyle(primaryText)
                            }

                            Text("Automatically combines debts to reduce the total number of repayments between group members.")
                                .font(.caption1())
                                .foregroundStyle(disableText)
                        }
                    }
                    .padding(.top, -4)
                    .padding(.horizontal, 16)
                }

                GroupListEditCellView(text: "Leave group", showArrowBtn: true,
                                      isDestructive: false, onTap: onLeaveGroupTap)

                GroupListEditCellView(text: "Delete group", fontColor: errorColor,
                                      isDestructive: true, onTap: onDeleteGroupTap)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
    }
}
