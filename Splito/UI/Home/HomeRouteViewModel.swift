//
//  HomeRouteViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/06/24.
//

import SwiftUI
import Data

class HomeRouteViewModel: ObservableObject {

    @Inject private var preference: SplitoPreference

    @Published var isTabBarVisible: Bool = true
    @Published var openProfileView: Bool = false

    @Published var selectedTab: Int = 0

    func openUserProfileIfNeeded() {
        if preference.isVerifiedUser {
            if preference.user == nil || (preference.user?.firstName == nil) || (preference.user?.firstName == "") {
                openProfileView = true
            }
        }
    }

    func setSelectedTab(_ index: Int) {
        selectedTab = index
    }

    func dismissProfileView() {
        openProfileView = false
    }

    func switchToActivityLog() {
        selectedTab = 1
    }
}
