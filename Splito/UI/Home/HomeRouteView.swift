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
    @State private var isKeyboardVisible = false

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
                    .offset(y: isKeyboardVisible ? 150 : 0)
            )
            .fullScreenCover(isPresented: $viewModel.openExpenseSheet) {
                ExpenseRouteView(groupId: viewModel.selectedGroupId)
            }
            .sheet(isPresented: $viewModel.openProfileView) {
                UserProfileView(viewModel: UserProfileViewModel(router: nil, isOpenFromOnboard: true, onDismiss: viewModel.dismissProfileView))
                    .interactiveDismissDisabled()
            }
        }
        .onAppear {
            viewModel.openUserProfileIfNeeded()
            addKeyboardObservers()
        }
        .onDisappear(perform: removeKeyboardObservers)
    }

    private func addKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
            withAnimation {
                isKeyboardVisible = true
            }
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
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
