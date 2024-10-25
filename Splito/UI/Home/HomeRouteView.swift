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
        VStack {
            TabView(selection: $viewModel.selectedTab) {
                GroupRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                    .tabItem {
                        Label {
                            Text("Groups")
                        } icon: {
                            Image(.groupFillIcon)
                        }
                    }
                    .tag(0)

                ActivityLogRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                    .tabItem {
                        Label {
                            Text("Activity")
                        } icon: {
                            Image(.activityFillIcon)
                        }
                    }
                    .tag(1)

                AccountRouteView(isTabBarVisible: $viewModel.isTabBarVisible)
                    .tabItem {
                        Label {
                            Text("Account")
                        } icon: {
                            Image(.profileFillIcon)
                        }
                    }
                    .tag(2)
            }
        }
        .tint(primaryText)
        .onAppear(perform: viewModel.openUserProfileIfNeeded)
        .sheet(isPresented: $viewModel.openProfileView) {
            UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true, onDismiss: viewModel.dismissProfileView))
                .interactiveDismissDisabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showActivityLog)) { _ in
            viewModel.switchToActivityLog()
        }
    }
}
