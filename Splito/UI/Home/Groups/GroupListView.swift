//
//  GroupListView.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import SwiftUI
import BaseStyle
import Data
import Kingfisher

struct GroupListView: View {

    @ObservedObject var viewModel: GroupListViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else {
                VStack(spacing: 0) {
                    if case .noGroup = viewModel.groupListState {
                        CreateGroupState(viewModel: .constant(viewModel))
                    } else if case .hasGroup(let groups) = viewModel.groupListState {
                        VSpacer(20)

                        HStack {
                            Text("You are all settle up!")
                                .font(.subTitle4(19))
                                .foregroundColor(primaryText)
                            Spacer()
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .resizable()
                                .foregroundColor(primaryText)
                                .frame(width: 26, height: 26)
                        }

                        VSpacer(20)

                        ScrollView(showsIndicators: false) {
                            VSpacer(10)

                            LazyVStack(spacing: 16) {
                                ForEach(groups) { group in
                                    GroupListCellView(group: group)
                                        .onTapGesture {
                                            viewModel.handleGroupItemTap(group)
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay {
                    if viewModel.groupListState != .noGroup {
                        FloatingAddGroupButton(showMenu: $viewModel.showGroupMenu,
                                               joinGroupTapped: viewModel.handleJoinGroupBtnTap,
                                               createGroupTapped: viewModel.handleCreateGroupBtnTap)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
    }
}

private struct GroupListCellView: View {

    let group: Groups

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            GroupProfileImageView(imageUrl: group.imageUrl)

            Text(group.name)
                .font(.subTitle2())
                .foregroundColor(primaryText)

            Spacer()

            Text("no expences")
                .font(.caption)
        }
        .background(backgroundColor)
    }
}

private struct CreateGroupState: View {

    @Binding var viewModel: GroupListViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You do not have any groups yet.")
                .font(.Header1(22))
                .foregroundColor(primaryText)

            Text("Groups make it easy to split apartment bills, share travel expenses, and more.")
                .font(.subTitle3(15))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            CreateGroupButtonView(onClick: viewModel.handleCreateGroupBtnTap)
        }
        .padding(.horizontal, 22)
    }
}

private struct CreateGroupButtonView: View {

    let onClick: () -> Void

    var body: some View {
        Button {
            onClick()
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
        .buttonStyle(.scale)
    }
}

#Preview {
    GroupListView(viewModel: GroupListViewModel(router: .init(root: .GroupListView)))
}
