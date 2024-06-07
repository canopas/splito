//
//  HomeRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/02/24.
//

import Data
import BaseStyle
import SwiftUI

struct HomeRouteView: View {

    @StateObject private var viewModel = HomeRouteViewModel()

    var body: some View {
        ZStack {
            TabView {
                GroupRouteView(onGroupSelected: viewModel.setSelectedGroupId(_:))
                    .tabItem {
                        Label("Groups", systemImage: "person.2")
                    }
                    .tag(0)

                AccountRouteView()
                    .tabItem {
                        Label("Account", systemImage: "person.crop.square")
                    }
                    .tag(1)
            }
            .tint(primaryColor)
            .overlay(
                CenterFabButton(onClick: viewModel.openAddExpenseSheet)
            )
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

struct CenterFabButton: View {

    var onClick: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button {
                    onClick()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 43, height: 43)
                        .tint(primaryColor)
                        .background(backgroundColor)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(.vertical, 1)

                Spacer()
            }
        }
    }
}
