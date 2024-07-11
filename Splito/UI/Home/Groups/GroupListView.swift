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

    @StateObject var viewModel: GroupListViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else {
                VStack(spacing: 0) {
                    if case .noGroup = viewModel.groupListState {
                        CreateGroupState(viewModel: .constant(viewModel))
                    } else if case .hasGroup = viewModel.groupListState {
                        VSpacer(16)

                        GroupListHeaderView(expense: viewModel.usersTotalExpense)

                        VSpacer(20)

                        if viewModel.showSearchBar {
                            SearchBar(text: $viewModel.searchedGroup, isFocused: $isFocused,
                                      placeholder: "Search groups", showCancelButton: true,
                                      clearButtonMode: .never, onCancel: viewModel.onSearchBarCancelBtnTap)
                            .padding(.horizontal, 4)
                            .focused($isFocused)
                            .onAppear {
                                isFocused = true
                            }
                        }

                        GroupListWithDetailView(viewModel: viewModel)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: viewModel.handleSearchBarTap) {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .scaledToFit()
                }
                .foregroundStyle(primaryText)
                .hidden(viewModel.groupListState == .noGroup)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: viewModel.handleCreateGroupBtnTap) {
                        Label("Create group", systemImage: "plus.circle")
                    }
                    .hidden(viewModel.groupListState == .noGroup)
                    Button(action: viewModel.handleJoinGroupBtnTap) {
                        Label("Join group", systemImage: "person.2")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14).weight(.bold))
                        .foregroundStyle(primaryText)
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .onAppear(perform: viewModel.fetchGroups)
        .onDisappear {
            isFocused = false
        }
    }
}

private struct GroupListHeaderView: View {

    var expense: Double

    var body: some View {
        HStack {
            if expense == 0 {
                Text("You are all settle up!")
                    .font(.Header4())
                    .foregroundStyle(primaryText)
            } else {
                let isOwed = expense < 0
                Group {
                    Text("Overall, \(isOwed ? "you owe" : "you are owed")  ")
                        .foregroundColor(primaryText)
                    + Text("\(expense.formattedCurrency)")
                        .foregroundColor(isOwed ? amountBorrowedColor : amountLentColor)
                }
                .font(.subTitle4(19))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

private struct GroupListWithDetailView: View {

    @ObservedObject var viewModel: GroupListViewModel

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VSpacer(10)
                LazyVStack(spacing: 16) {
                    if viewModel.filteredGroups.isEmpty {
                        GroupNotFoundView(geometry: geometry, searchedGroup: viewModel.searchedGroup)
                    } else {
                        ForEach(viewModel.filteredGroups, id: \.group.id) { group in
                            GroupListCellView(group: group, viewModel: viewModel)
                                .onTapGesture {
                                    viewModel.handleGroupItemTap(group.group)
                                }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct GroupNotFoundView: View {

    let geometry: GeometryProxy
    let searchedGroup: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VSpacer()

            Text("No results found for \"\(searchedGroup)\"")
                .font(.subTitle2())
                .lineSpacing(2)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            VSpacer()
        }
        .frame(minHeight: geometry.size.height - 50, maxHeight: .infinity, alignment: .center)
    }
}

private struct GroupListCellView: View {

    let group: GroupInformation
    var viewModel: GroupListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 20) {
                GroupProfileImageView(imageUrl: group.group.imageUrl)

                Text(group.group.name)
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)

                Spacer()

                let isBorrowed = group.oweAmount < 0
                VStack(alignment: .trailing, spacing: 4) {
                    if group.oweAmount == 0 {
                        Text(group.hasExpenses ? "settled up" : "no expense")
                            .font(.body1(12))
                            .foregroundStyle(secondaryText)
                    } else {
                        Text(isBorrowed ? "you owe" : "you are owed")
                            .font(.body1(12))

                        Text(group.oweAmount.formattedCurrency)
                            .font(.body1(16))
                    }
                }
                .lineLimit(1)
                .foregroundStyle(isBorrowed ? amountBorrowedColor : amountLentColor)
            }

            HStack(alignment: .top, spacing: 20) {

                HSpacer(50) // width of image size for padding

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.memberOweAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                        let name = viewModel.getMemberData(from: group.members, of: memberId)?.nameWithLastInitial ?? "Unknown"
                        GroupExpenseMemberOweView(name: name, amount: amount)
                    }
                }
            }
        }
        .background(backgroundColor)
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double

    var body: some View {
        if amount > 0 {
            Group {
                Text("\(name.localized) owes you ")
                    .foregroundColor(secondaryText)
                + Text("\(amount.formattedCurrency)")
                    .foregroundColor(amountLentColor)
            }
            .font(.body1(14))
        } else if amount < 0 {
            Group {
                Text("You owe \(name) ")
                    .foregroundColor(secondaryText)
                + Text("\(amount.formattedCurrency)")
                    .foregroundColor(amountBorrowedColor)
            }
            .font(.body1(14))
        }
    }
}

private struct CreateGroupState: View {

    @Binding var viewModel: GroupListViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You do not have any groups yet.")
                .font(.Header1(22))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            Text("Groups make it easy to split apartment bills, share travel expenses, and more.")
                .font(.subTitle3(15))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            CreateGroupButtonView(onClick: viewModel.handleCreateGroupBtnTap)
        }
        .padding(.horizontal, 30)
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
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 22)

                Text("Start a group")
                    .foregroundStyle(.white)
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
