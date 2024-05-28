//
//  MainRouteViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 28/05/24.
//

import Data
import Combine
import UIKit

class MainRouteViewModel: ObservableObject {

    @Inject var preference: SplitoPreference

    @Published var showOnboardFlow: Bool = true

    private var cancellable = Set<AnyCancellable>()

    init() {
        setupBindings()
        updateOnboardFlowIfNeeded()
    }

    func updateOnboardFlowIfNeeded() {
        showOnboardFlow = !preference.isVerifiedUser
    }

    private func setupBindings() {
        preference.$isVerifiedUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateOnboardFlowIfNeeded()
            }
            .store(in: &cancellable)
    }
}
