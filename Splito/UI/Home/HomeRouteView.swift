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
                    .environmentObject(viewModel)

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
        .onAppear(perform: viewModel.openProfileOrOnboardFlow)
        .sheet(isPresented: $viewModel.openProfileView) {
            UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true, onDismiss: viewModel.dismissProfileView))
                .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $viewModel.openOnboardFlow) {
            OnboardRouteView(onDismiss: viewModel.dismissOnboardFlow)
                .interactiveDismissDisabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showActivityLog)) { notification in
            if let activityId = notification.userInfo?["activityId"] as? String {
                viewModel.switchToActivityLog(activityId: activityId)
            }
        }
    }
}
