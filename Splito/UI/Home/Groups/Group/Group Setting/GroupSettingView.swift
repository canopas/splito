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

    @ObservedObject var viewModel: GroupSettingViewModel

    var body: some View {
        VStack {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else if case .success(let group) = viewModel.currentViewState {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VSpacer(20)

                        GroupTitleView(group: group)
                            .onTapGesture {
                                viewModel.handleEditGroupTap()
                            }

                        Divider()
                            .frame(height: 1)
                            .background(disableLightText)

                        VSpacer(10)

                        GroupMembersView(members: viewModel.members) {
                            viewModel.handleAddMemberTap()
                        }
                    }
                }
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Group settings", displayMode: .inline)
    }
}

private struct GroupTitleView: View {

    let group: Groups

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            GroupProfileImageView(imageUrl: group.imageUrl)

            Text(group.name)
                .font(.subTitle1())
                .foregroundColor(primaryText)

            Spacer()

            Text("Edit")
                .font(.bodyBold(17))
                .foregroundColor(primaryColor)
        }
        .padding(.horizontal, 22)
    }
}

private struct GroupMembersView: View {

    var members: [AppUser]
    var onAddMemberTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Group members")
                .font(.subTitle2())
                .foregroundColor(primaryText)

            HStack(spacing: 30) {
                Image(systemName: "person.badge.plus")
                    .resizable()
                    .frame(width: 26, height: 26)

                Text("Add people to group")
                    .font(.subTitle1())
            }
            .frame(height: 40)
            .padding(.leading, 16)
            .foregroundColor(primaryText)
            .onTapGesture {
                onAddMemberTap()
            }

            LazyVStack(spacing: 20) {
                ForEach(members) { member in
                    GroupMemberCellView(member: member)
                }
            }
        }
        .padding(.horizontal, 22)
    }
}

private struct GroupMemberCellView: View {

    @Inject var preference: SplitoPreference

    let member: AppUser
    var userName: String?
    var subInfo: String?

    init(member: AppUser) {
        self.member = member
        if let user = preference.user, member.id == user.id {
            userName = "You"
        } else {
            userName = (member.firstName ?? "") + " " + (member.lastName ?? "")
        }
        userName = (userName ?? "").isEmpty ? "Unknown" : userName

        if let emailId = member.emailId {
            subInfo = emailId
        } else if let phoneNumber = member.phoneNumber {
            subInfo = phoneNumber
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            VStack(alignment: .leading, spacing: 5) {
                Text(userName ?? "")
                    .lineLimit(1)
                    .font(.subTitle2())
                    .foregroundColor(primaryText)

                Text(subInfo ?? "")
                    .lineLimit(1)
                    .font(.subTitle3())
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Text("settled up")
                .font(.subTitle3())
                .foregroundColor(secondaryText)
        }
    }
}

#Preview {
    GroupSettingView(viewModel: GroupSettingViewModel(router: .init(root: .GroupSettingView(groupId: "")), groupId: ""))
}
