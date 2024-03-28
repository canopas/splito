//
//  ChoosePayerViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Combine

class ChoosePayerViewModel: BaseViewModel, ObservableObject {

    @Published var groupId: String
    @Published var currentViewState: ViewState = .initial

    init(groupId: String) {
        self.groupId = groupId
        super.init()

        self.fetchMembers()
    }

    func fetchMembers() {
        currentViewState = .loading
    }
}

extension ChoosePayerViewModel {
    enum ViewState {
        case initial
        case loading
        case success
    }
}
