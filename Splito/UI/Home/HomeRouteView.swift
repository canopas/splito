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
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
                GroupRouteView(onGroupSelected: viewModel.setSelectedGroupId(_:))
                    .onAppear {
                        viewModel.setLastSelectedTab(0)
                    }
                    .tabItem {
                        Label("Groups", systemImage: "person.2")
                    }
                    .tag(0)

                Text("")
                    .tabItem {
                        Label("Add expense", systemImage: "plus.circle.fill")
                    }
                    .tag(1)

                AccountRouteView()
                    .onAppear {
                        viewModel.setLastSelectedTab(2)
                    }
                    .tabItem {
                        Label("Account", systemImage: "person.crop.square")
                    }
                    .tag(2)
            }
            .tint(primaryColor)
            .onChange(of: viewModel.selectedTab) { newValue in
                if newValue == 1 {
                    viewModel.openAddExpenseSheet()
                }
            }
            .fullScreenCover(isPresented: $viewModel.openExpenseSheet) {
                ExpenseRouteView(groupId: viewModel.selectedGroupId)
            }
            .sheet(isPresented: $viewModel.openProfileView) {
                UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true, onDismiss: viewModel.dismissProfileView))
                    .interactiveDismissDisabled()
            }
        }
        .onAppear(perform: viewModel.openUserProfileIfNeeded)
    }
}
