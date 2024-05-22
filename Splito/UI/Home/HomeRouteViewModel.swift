//
//  HomeRouteViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/05/24.
//

import Data
import Combine

class HomeRouteViewModel: ObservableObject {

    @Inject var preference: SplitoPreference

    @Published var selectedTab: Int = 0
    @Published var shouldOpenExpenseSheet = false
    @Published var shouldOpenProfileView = false

    func checkForForceProfileInput() {
        if preference.isVerifiedUser {
            if preference.user == nil || (preference.user?.firstName == nil) {
                shouldOpenProfileView = true
            }
        }
    }
}
