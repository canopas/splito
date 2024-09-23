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
            TabView(selection: $viewModel.selectedTab) {
                GroupRouteView()
                    .onAppear {
                        viewModel.setLastSelectedTab(0)
                    }
                    .tabItem {
                        Label("Groups", systemImage: "person.2")
                    }
                    .tag(0)

                Spacer()
                    .tabItem {
                        EmptyView()
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
            .fullScreenCover(isPresented: $viewModel.openExpenseSheet) {
                ExpenseRouteView()
            }
            .sheet(isPresented: $viewModel.openProfileView) {
                UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true, onDismiss: viewModel.dismissProfileView))
                    .interactiveDismissDisabled()
            }

            AddExpenseButtonView(onClick: viewModel.openAddExpenseSheet)
        }
        .ignoresSafeArea(.keyboard) // Useful so the button doesn't move around on keyboard show
        .onAppear(perform: viewModel.openUserProfileIfNeeded)
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
