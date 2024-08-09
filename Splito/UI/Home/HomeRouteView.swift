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
                GroupRouteView()
                    .onAppear {
                        viewModel.setLastSelectedTab(0)
                    }
                    .tabItem {
                        Label("Groups", systemImage: "person.2")
                    }
                    .tag(0)

                Text("")
                    .tabItem {
                        Label("", image: "AddExpense")
                    }
                    .tag(1)

                AccountRouteView()
                    .onAppear {
                        viewModel.setLastSelectedTab(2)
                    }
                    .tabItem {
                        Label("Account", systemImage: "person")
                    }
                    .tag(2)
            }
            .tint(primaryText)
            .onChange(of: viewModel.selectedTab) { newValue in
                if newValue == 1 {
                    viewModel.openAddExpenseSheet()
                }
            }
            .fullScreenCover(isPresented: $viewModel.openExpenseSheet) {
                ExpenseRouteView()
            }
            .sheet(isPresented: $viewModel.openProfileView) {
                UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true, onDismiss: viewModel.dismissProfileView))
                    .interactiveDismissDisabled()
            }
        }
        .onAppear(perform: viewModel.openUserProfileIfNeeded)
    }
}
