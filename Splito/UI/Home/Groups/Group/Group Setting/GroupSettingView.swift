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
        VStack {
            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .initial = viewModel.currentViewState {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        VSpacer(20)

                        GroupTitleView(group: viewModel.group)
                            .onTouchGesture {
                                viewModel.handleEditGroupTap()
                            }

                        GroupMembersView(group: viewModel.group, members: viewModel.members, oweAmount: viewModel.amountOweByMember,
                                         onAddMemberTap: viewModel.handleAddMemberTap, onMemberTap: viewModel.handleMemberTap(member:))

                        GroupAdvanceSettingsView(isDebtSimplified: $viewModel.isDebtSimplified, isDisable: !viewModel.isAdmin,
                                                 onLeaveGroupTap: viewModel.handleLeaveGroupTap,
                                                 onDeleteGroupTap: viewModel.handleDeleteGroupTap)

                        Spacer(minLength: 20)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Group settings", displayMode: .inline)
        .confirmationDialog("", isPresented: $viewModel.showLeaveGroupDialog, titleVisibility: .hidden) {
            Button("Leave Group") {
                viewModel.onRemoveAndLeaveFromGroupTap()
            }
        }
        .confirmationDialog("", isPresented: $viewModel.showRemoveMemberDialog, titleVisibility: .hidden) {
            Button("Remove from group") {
                viewModel.onRemoveAndLeaveFromGroupTap()
            }
        }
        .onAppear {
            viewModel.fetchGroupDetails()
        }
    }
}

private struct GroupTitleView: View {

    let group: Groups?

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                GroupProfileImageView(imageUrl: group?.imageUrl)

                Text(group?.name ?? "")
                    .font(.subTitle1())
                    .foregroundStyle(primaryText)

                Spacer()

                Text("Edit")
                    .font(.bodyBold(17))
                    .foregroundStyle(primaryColor)
            }
            .padding(.horizontal, 22)

            Divider()
                .frame(height: 1)
                .background(outlineColor)
        }
    }
}

private struct GroupMembersView: View {

    let group: Groups?
    var members: [AppUser]
    var oweAmount: [String: Double]

    var onAddMemberTap: () -> Void
    var onMemberTap: (AppUser) -> Void

    init(group: Groups?, members: [AppUser], oweAmount: [String: Double], onAddMemberTap: @escaping () -> Void, onMemberTap: @escaping (AppUser) -> Void) {
        self.group = group
        self.members = members
        self.oweAmount = oweAmount
        self.onAddMemberTap = onAddMemberTap
        self.onMemberTap = onMemberTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Group members")
                .font(.bodyBold())
                .foregroundStyle(primaryText)

            GroupListEditCellView(icon: "person.badge.plus", text: "Add people to group", onTap: onAddMemberTap)

            LazyVStack(spacing: 20) {
                ForEach(members) { member in
                    GroupMemberCellView(member: member, amount: oweAmount[member.id] ?? 0, isAdmin: member.id == group?.createdBy)
                        .onTouchGesture {
                            onMemberTap(member)
                        }
                }
            }
        }
        .padding(.horizontal, 22)
    }
}

private struct GroupAdvanceSettingsView: View {

    @Binding var isDebtSimplified: Bool

    var isDisable: Bool
    var onLeaveGroupTap: () -> Void
    var onDeleteGroupTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Advanced settings")
                .font(.bodyBold())

            HStack(alignment: .top, spacing: 30) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .resizable()
                    .frame(width: 25, height: 22)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $isDebtSimplified) {
                        Text("Simplify group debts")
                            .font(.body1(18))
                    }

                    Text("Automatically combines debts to reduce the total number of repayments between group members.")
                        .font(.body2())
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(.top, -6)
            .padding(.leading, 16)

            GroupListEditCellView(icon: "arrow.left.square", text: "Leave group",
                                  isDistructive: true, onTap: onLeaveGroupTap)

            GroupListEditCellView(icon: "trash", text: "Delete group", isDisable: isDisable,
                                  isDistructive: true, onTap: onDeleteGroupTap)
        }
        .padding(.horizontal, 22)
        .foregroundStyle(primaryText)
    }
}

private struct GroupListEditCellView: View {

    var icon: String
    var text: String
    var isDisable: Bool = false
    var isDistructive: Bool = false

    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 22, height: 22)

            Text(text.localized)
                .font(.body1(18))
        }
        .padding(.leading, 16)
        .foregroundStyle(isDisable ? disableText : (isDistructive ? awarenessColor : primaryText))
        .onTouchGesture {
            onTap()
        }
        .disabled(isDisable)
    }
}

private struct GroupMemberCellView: View {

    @Inject var preference: SplitoPreference

    let member: AppUser
    let amount: Double
    let isAdmin: Bool

    private var userName: String {
        if let user = preference.user, member.id == user.id {
            return "You"
        } else {
            return member.fullName
        }
    }

    private var subInfo: String {
        if let emailId = member.emailId {
            return emailId
        } else if let phoneNumber = member.phoneNumber {
            return phoneNumber
        } else {
            return "No email address"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 2) {
                    Text(userName)
                        .lineLimit(1)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    if isAdmin {
                        Text(" (Admin)")
                            .font(.caption)
                            .foregroundColor(secondaryText)
                    }
                }

                Text(subInfo)
                    .lineLimit(1)
                    .font(.subTitle3())
                    .foregroundStyle(secondaryText)
            }

            Spacer()

            let isBorrowed = amount < 0
            VStack(alignment: .trailing, spacing: 4) {
                if amount == 0 {
                    Text("settled up")
                        .font(.body1(13))
                        .foregroundStyle(secondaryText)
                } else {
                    Text(isBorrowed ? "owes" : "gets back")
                        .font(.body1(13))

                    Text(amount.formattedCurrency)
                        .font(.body1())
                }
            }
            .lineLimit(1)
            .foregroundStyle(isBorrowed ? amountBorrowedColor : amountLentColor)
        }
    }
}

#Preview {
    GroupSettingView(viewModel: GroupSettingViewModel(router: .init(root: .GroupSettingView(groupId: "")), groupId: ""))
}
