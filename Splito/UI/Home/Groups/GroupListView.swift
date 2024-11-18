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
    @State private var sheetHeight: CGFloat = .zero

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.currentViewState || .somethingWentWrong == viewModel.currentViewState {
                ErrorView(isForNoInternet: viewModel.currentViewState == .noInternet, onClick: viewModel.fetchGroupsInitialData)
            } else if case .loading = viewModel.currentViewState {
                LoaderView()
                Spacer(minLength: 60)
            } else {
                VStack(spacing: 0) {
                    if case .noGroup = viewModel.groupListState {
                        NoGroupsState(onCreateBtnTap: viewModel.handleCreateGroupBtnTap)
                    } else if case .hasGroup = viewModel.groupListState {
                        VSpacer(16)

                        VStack(spacing: 16) {
                            GroupListTabBarView(selectedTab: viewModel.selectedTab,
                                                onSelect: viewModel.handleTabItemSelection(_:))

                            if viewModel.selectedTab == .all {
                                GroupListHeaderView(totalOweAmount: viewModel.totalOweAmount)
                                    .padding(.bottom, viewModel.showSearchBar ? 0 : 2)
                            }
                        }
                        .onTapGestureForced {
                            UIApplication.shared.endEditing()
                        }

                        if viewModel.showSearchBar {
                            SearchBar(text: $viewModel.searchedGroup, isFocused: $isFocused, placeholder: "Search groups")
                                .padding(.vertical, -7)
                                .padding(.horizontal, 3)
                                .overlay(content: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(outlineColor, lineWidth: 1)
                                })
                                .focused($isFocused)
                                .onAppear {
                                    isFocused = true
                                }
                                .padding([.horizontal, .top], 16)
                                .padding(.bottom, 8)
                        }

                        GroupListWithDetailView(isFocused: $isFocused, viewModel: viewModel) {
                            isFocused = false
                        }
                    }
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Groups")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(systemImageName: "magnifyingglass", onClick: viewModel.handleSearchBarTap)
                    .hidden(viewModel.groupListState == .noGroup)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: viewModel.handleCreateGroupBtnTap) {
                        Label("Create group", systemImage: "plus.circle")
                    }
                    Button(action: viewModel.handleJoinGroupBtnTap) {
                        Label("Join group", systemImage: "person.2")
                    }
                } label: {
                    SystemPlusButton()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.showScrollToTopBtn {
                VStack(spacing: 0) {
                    Spacer()
                    AddExpenseButtonView(onClick: viewModel.openAddExpenseSheet)
                        .padding([.bottom, .trailing], 16)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(isPresented: $viewModel.showActionSheet) {
            GroupActionSheetView(onSelectionWith: viewModel.handleOptionSelection(with:))
                .fixedSize(horizontal: false, vertical: true)
                .modifier(BottomSheetHeightModifier(height: $sheetHeight))
                .presentationDetents([.height(sheetHeight)])
                .presentationCornerRadius(24)
        }
        .fullScreenCover(isPresented: $viewModel.showAddExpenseSheet) {
            ExpenseRouteView()
        }
        .fullScreenCover(isPresented: $viewModel.showCreateGroupSheet) {
            NavigationStack {
                CreateGroupView(viewModel: CreateGroupViewModel(router: viewModel.router, group: viewModel.selectedGroup))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showJoinGroupSheet) {
            NavigationStack {
                JoinMemberView(viewModel: JoinMemberViewModel(router: viewModel.router))
            }
        }
    }
}

private struct GroupListTabBarView: View {

    let selectedTab: GroupListTabType
    let onSelect: ((GroupListTabType) -> Void)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GroupListTabType.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.tabItem)
                        .font(tab == selectedTab ? .Header4(14) : .body2())
                        .lineLimit(1)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .foregroundStyle(tab == selectedTab ? containerColor : disableText)
                        .background(tab == selectedTab ? primaryDarkColor : container2Color)
                        .cornerRadius(30)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct GroupListHeaderView: View {

    let totalOweAmount: Double

    var body: some View {
        HStack(spacing: 0) {
            if totalOweAmount == 0 {
                Text("You are all settle up!")
                    .font(.Header3())
                    .foregroundStyle(primaryText)
            } else {
                let isOwed = totalOweAmount < 0
                HStack(spacing: 0) {
                    Text("Overall, \(isOwed ? "you owe" : "you are owed")  ")
                        .foregroundStyle(primaryText)

                    Spacer()

                    Text("\(totalOweAmount.formattedCurrency)")
                        .foregroundStyle(isOwed ? errorColor : successColor)
                }
                .font(.Header3())
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

private struct NoGroupsState: View {

    let onCreateBtnTap: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    Image(.emptyGroupList)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 156, height: 156)
                        .padding(.bottom, 40)

                    Text("No groups yet.")
                        .font(.Header1(22))
                        .foregroundStyle(primaryText)
                        .padding(.bottom, 16)

                    Text("You don’t have any groups. Groups that you a part of will be listed here.")
                        .font(.subTitle1())
                        .foregroundStyle(disableText)

                    PrimaryButton(text: "Create group", onClick: onCreateBtnTap)
                        .padding(.top, 16)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: geometry.size.height - 100, maxHeight: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct GroupActionSheetView: View {

    let onSelectionWith: (_ option: OptionList) -> Void

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 16)
                .fill(outlineColor)
                .frame(width: 40, height: 4)
                .padding(.vertical, 22)

            ForEach(OptionList.allCases, id: \.self) { option in
                Button {
                    onSelectionWith(option)
                } label: {
                    HStack(spacing: 16) {
                        Image(option.image)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(option != .deleteGroup ? primaryText : errorColor)

                        Text(option.title)
                            .font(.subTitle2())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(option != .deleteGroup ? primaryText : errorColor)
                }
                .padding(option != .deleteGroup ? .vertical : .top, 20)
                .padding(.horizontal, 16)

                if OptionList.allCases.last != option {
                    Divider()
                        .frame(height: 1)
                        .background(dividerColor)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Tab Types
enum GroupListTabType: Int, CaseIterable {
    case all, settled, unsettled

    var tabItem: String {
        switch self {
        case .all:
            return "All"
        case .settled:
            return "Settled"
        case .unsettled:
            return "Unsettled"
        }
    }
}

enum OptionList: CaseIterable {
    case editGroup
    case deleteGroup

    var title: String {
        switch self {
        case .editGroup:
            return "Edit group"
        case .deleteGroup:
            return "Delete group"
        }
    }

    var image: ImageResource {
        switch self {
        case .editGroup:
            return .editPencilIcon
        case .deleteGroup:
            return .binIcon
        }
    }
}

struct AddExpenseButtonView: View {

    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 4) {
                SystemPlusButton(color: primaryLightText)

                Text("Expense")
                    .font(.buttonText())
                    .foregroundStyle(primaryLightText)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(primaryColor)
            .cornerRadius(30)
        }
    }
}

struct SystemPlusButton: View {

    var imageName: String = "plus"
    var size: Double = 16
    var imageWeight: Font.Weight = .medium
    var color: Color = primaryText

    var body: some View {
        Image(systemName: imageName)
            .font(.system(size: size, weight: imageWeight))
            .foregroundStyle(color)
    }
}
