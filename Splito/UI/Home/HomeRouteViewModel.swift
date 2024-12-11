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
    @Published var openOnboardFlow: Bool = false

    @Published var selectedTab: Int = 0
    @Published var activityLogId: String?

    func openProfileOrOnboardFlow() {
        if preference.user == nil {
            openOnboardFlow = true
        } else if preference.isVerifiedUser && (preference.user?.firstName == nil || preference.user?.firstName == "") {
            openProfileView = true
        }
    }

    func setSelectedTab(_ index: Int) {
        selectedTab = index
    }

    func dismissProfileView() {
        openProfileView = false
    }

    func dismissOnboardFlow() {
        openOnboardFlow = false
    }

    func switchToActivityLog(activityId: String) {
        activityLogId = activityId
        selectedTab = 1
    }
}
