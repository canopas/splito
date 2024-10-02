//
//  HomeRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/02/24.
//

import BaseStyle
import SwiftUI

struct HomeRouteView: View {

    @StateObject private var viewModel = HomeRouteViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch viewModel.selectedTab {
                case 0:
                    GroupRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                        .onAppear {
                            viewModel.setLastSelectedTab(0)
                        }
                case 2:
                    AccountRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                        .onAppear {
                            viewModel.setLastSelectedTab(2)
                        }
                default:
                    Color.clear // For the empty tab space
                }
            }

            // Conditionally show or hide the tab bar
            if viewModel.isTabBarVisible {
                CustomTabBarView(selectedTab: $viewModel.selectedTab,
                                 onAddExpense: viewModel.openAddExpenseSheet,
                                 onTabItemClick: viewModel.setSelectedTab(_:))
            }
        }
        .ignoresSafeArea(.keyboard) // Useful so the button doesn't move around on keyboard show
        .onAppear(perform: viewModel.openUserProfileIfNeeded)
        .fullScreenCover(isPresented: $viewModel.openExpenseSheet) {
            ExpenseRouteView()
        }
        .sheet(isPresented: $viewModel.openProfileView) {
            UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true,
                                                            onDismiss: viewModel.dismissProfileView))
            .interactiveDismissDisabled()
        }
    }
}

struct CustomTabBarView: View {
    @Binding var selectedTab: Int

    let onAddExpense: () -> Void
    let onTabItemClick: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(dividerColor.ignoresSafeArea(edges: [.bottom, .horizontal]))

            HStack {
                TabBarItemView(selectedTab: $selectedTab, tabIndex: 0, image: .groupIcon,
                               selectedImage: .groupFillIcon, label: "Groups", onTabItemClick: onTabItemClick)

                AddExpenseButtonView(onClick: onAddExpense)

                TabBarItemView(selectedTab: $selectedTab, tabIndex: 2, image: .profileIcon,
                               selectedImage: .profileFillIcon, label: "Account", onTabItemClick: onTabItemClick)
            }
            .padding(.top, 5)
            .background(surfaceColor.ignoresSafeArea(edges: [.bottom, .horizontal]))
        }
    }
}

struct TabBarItemView: View {

    @Binding var selectedTab: Int

    let tabIndex: Int
    let image: ImageResource
    let selectedImage: ImageResource
    let label: String

    let onTabItemClick: (Int) -> Void

    var body: some View {
        Button {
            onTabItemClick(tabIndex)
        } label: {
            HStack {
                if tabIndex == 2 { Spacer() }

                VStack(spacing: 1) {
                    Image(selectedTab == tabIndex ? selectedImage : image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)

                    Text(label)
                        .font(.caption1())
                        .foregroundStyle(selectedTab == tabIndex ? primaryText : disableText)
                }

                if tabIndex == 0 { Spacer() }
            }
            .padding(.horizontal, isIpad ? 150 : 50)
        }
    }
}

private struct AddExpenseButtonView: View {

    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Image(systemName: "plus")
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .frame(width: 16, height: 16)
                .foregroundStyle(primaryLightText)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
        }
        .background(primaryColor)
        .cornerRadius(30)
    }
}
