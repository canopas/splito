//
//  HomeRouteViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 06/06/24.
//

import Foundation
import Combine
import Data

class HomeRouteViewModel: ObservableObject {

    @Inject var preference: SplitoPreference

    @Published var openExpenseSheet = false
    @Published var openProfileView = false
    @Published var selectedGroupId: String?

    func onViewAppear() {
        if preference.isVerifiedUser {
            if preference.user == nil || (preference.user?.firstName == nil) || (preference.user?.firstName == "") {
                openProfileView = true
            }
        }
    }

    func setSelectedGroupId(_ groupId: String?) {
        selectedGroupId = groupId
    }
}
