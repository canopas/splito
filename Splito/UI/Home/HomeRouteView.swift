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

    @StateObject var viewModel = HomeRouteViewModel()

    var body: some View {
        UITabView(selection: $viewModel.selectedTab) {
            GroupRouteView()
                .tabItem("Groups", image: UIImage(systemName: "person.2.fill"))

            AccountRouteView()
                .tabItem("Account", image: UIImage(systemName: "person.crop.square"))
        }
        .tint(primaryColor)
        .overlay(
            CenterFabButton {
                viewModel.shouldOpenExpenseSheet = true
            }
        )
        .fullScreenCover(isPresented: $viewModel.shouldOpenExpenseSheet) {
            ExpenseRouteView {
                viewModel.shouldOpenExpenseSheet = false
            }
        }
        .sheet(isPresented: $viewModel.shouldOpenProfileView) {
            UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenedFromOnboard: true, onDismiss: {
                viewModel.shouldOpenProfileView = false
            }))
            .interactiveDismissDisabled()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.checkForForceProfileInput()
        }
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
