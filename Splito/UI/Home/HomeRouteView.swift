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
    @State private var selectedTab = 0
    @State var previousSelectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                GroupRouteView(onGroupSelected: viewModel.setSelectedGroupId(_:))
                    .onAppear(perform: {
                        previousSelectedTab = 0
                    })
                    .tabItem {
                        Label("Groups", systemImage: "person.2")
                    }
                    .tag(0)
                
                Text("Add Expense")
                    .tabItem {
                        CustomAddExpenseTab(selected: selectedTab == 1)
                    }
                    .tag(1)
                
                AccountRouteView()
                    .onAppear(perform: {
                        previousSelectedTab = 2
                    })
                    .tabItem {
                        Label("Account", systemImage: "person.crop.square")
                    }
                    .tag(2)
            }
            .tint(primaryColor)
            .onChange(of: selectedTab) { newValue in
                if newValue == 1 {
                    viewModel.openExpenseSheet = true
                    selectedTab = previousSelectedTab
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

struct CustomAddExpenseTab: View {
    var selected: Bool
    
    var body: some View {
        VStack {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(selected ? primaryColor : .gray)
            Text("Add Expense")
                .font(.caption)
                .foregroundColor(selected ? primaryColor : .gray)
        }
        .padding(.top, 6)
    }
}
