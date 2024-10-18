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
                case 1:
                    ActivityLogRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                case 2:
                    AccountRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                default:
                    Color.clear // For the empty tab space
                }
            }

            // Conditionally show or hide the tab bar
            if viewModel.isTabBarVisible {
                CustomTabBarView(selectedTab: $viewModel.selectedTab,
                                 onTabItemClick: viewModel.setSelectedTab(_:))
            }
        }
        .ignoresSafeArea(.keyboard) // Useful so the button doesn't move around on keyboard show
        .onAppear(perform: viewModel.openUserProfileIfNeeded)
        .sheet(isPresented: $viewModel.openProfileView) {
            UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true,
                                                            onDismiss: viewModel.dismissProfileView))
            .interactiveDismissDisabled()
        }
    }
}

struct CustomTabBarView: View {
    @Binding var selectedTab: Int

    let onTabItemClick: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(dividerColor.ignoresSafeArea(edges: [.bottom, .horizontal]))

            HStack {
                TabBarItemView(selectedTab: $selectedTab, tabIndex: 0, image: .groupIcon,
                               selectedImage: .groupFillIcon, label: "Groups", onTabItemClick: onTabItemClick)

                TabBarItemView(selectedTab: $selectedTab, tabIndex: 1, image: .activityIcon,
                               selectedImage: .activityFillIcon, label: "Activity", onTabItemClick: onTabItemClick)

                TabBarItemView(selectedTab: $selectedTab, tabIndex: 2, image: .profileIcon,
                               selectedImage: .profileFillIcon, label: "Account", onTabItemClick: onTabItemClick)
            }
            .padding(.vertical, 5)
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
                VStack(spacing: 1) {
                    Image(selectedTab == tabIndex ? selectedImage : image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)

                    Text(label.localized)
                        .font(.caption1())
                        .foregroundStyle(selectedTab == tabIndex ? primaryText : disableText)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
