//
//  HomeRouteViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/06/24.
//

import Foundation
import Combine
import Data

class HomeRouteViewModel: ObservableObject {

    @Inject private var preference: SplitoPreference

    @Published var openExpenseSheet = false
    @Published var openProfileView = false
    @Published var selectedGroupId: String?

    func openUserProfileIfNeeded() {
        if preference.isVerifiedUser {
            if preference.user == nil || (preference.user?.firstName == nil) || (preference.user?.firstName == "") {
                openProfileView = true
            }
        }
    }

    func setSelectedGroupId(_ groupId: String?) {
        selectedGroupId = groupId
    }

    func openAddExpenseSheet() {
        openExpenseSheet = true
    }

    func dismissProfileView() {
        openProfileView = false
    }
}
