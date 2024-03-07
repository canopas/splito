//
//  GroupHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data

class GroupHomeViewModel: BaseViewModel, ObservableObject {

    let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }
}
