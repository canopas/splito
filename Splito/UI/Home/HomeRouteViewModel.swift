//
//  HomeRouteViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/06/24.
//

import SwiftUI
import Combine
import Data

class HomeRouteViewModel: ObservableObject {

    @Inject private var preference: SplitoPreference

    @Published var openProfileView = false
    @Published var openExpenseSheet = false

    @Published var selectedTab = 0
    @Published private(set) var lastSelectedTab = 0
    @Published private(set) var selectedGroupId: String?

    func openUserProfileIfNeeded() {
        if preference.isVerifiedUser {
            if preference.user == nil || (preference.user?.firstName == nil) || (preference.user?.firstName == "") {
                openProfileView = true
            }
        }
    }

    func setLastSelectedTab(_ index: Int) {
        lastSelectedTab = index
    }

    func setSelectedGroupId(_ groupId: String?) {
        DispatchQueue.main.async {
            self.selectedGroupId = groupId
        }
    }

    func openAddExpenseSheet() {
        openExpenseSheet = true
        selectedTab = lastSelectedTab
    }

    func dismissProfileView() {
        openProfileView = false
    }
}
