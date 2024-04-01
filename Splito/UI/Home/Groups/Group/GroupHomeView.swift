//
//  GroupHomeView.swift
//  Splito
//
//  Created by Amisha Italiya on 05/03/24.
//

import SwiftUI
import BaseStyle

struct GroupHomeView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .noGroup = viewModel.groupState {
                CreateGroupState(viewModel: .constant(viewModel))
            } else if case .noMember = viewModel.groupState {
                AddMemberState(viewModel: .constant(viewModel))
            } else if case .hasMembers = viewModel.groupState {
                Text("Members are added now !")
                    .font(.title)
            }
        }
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle(viewModel.group?.name ?? "", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handleSettingButtonTap()
                } label: {
                    Image(systemName: "gearshape")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .foregroundColor(primaryColor)
            }
        }
    }
}

private struct AddMemberState: View {

    @Binding var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You're the only one here!")
                .font(.subTitle1())
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleAddMemberClick()
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.fill.badge.plus")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 32, height: 30)

                    Text("Invite members")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 22)
    }
}

private struct CreateGroupState: View {

    @Binding var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You do not have any groups yet.")
                .font(.Header1(22))
                .foregroundColor(primaryText)

            Text("Groups make it easy to split apartment bills, share travel expenses, and more.")
                .font(.subTitle3(15))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleCreateGroupClick()
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 42, height: 22)

                    Text("Start a group")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 10)
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 22)
    }
}

#Preview {
    GroupHomeView(viewModel: GroupHomeViewModel(router: .init(root: .GroupHomeView(groupId: "")), groupId: ""))
}
