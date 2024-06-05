//
//  GroupPaymentViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Combine
import Data
import SwiftUI

class GroupPaymentViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository

    @Published var amount: Double = 0
    @Published var payerUser: AppUser?
    @Published var payableUser: AppUser?
    @Published var viewState: ViewState = .initial

    let payerUserId: String
    let payableUserId: String
    private let groupId: String
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>, groupId: String, payerUserId: String, payableUserId: String, amount: Double) {
        self.router = router
        self.groupId = groupId
        self.payerUserId = payerUserId
        self.payableUserId = payableUserId
        self.amount = abs(amount)
        super.init()

        getPayerUserDetail()
        getPayableUserDetail()
    }

    private func getPayerUserDetail() {
        userRepository.fetchUserBy(userID: payerUserId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.payerUser = user
            }.store(in: &cancelable)
    }

    private func getPayableUserDetail() {
        userRepository.fetchUserBy(userID: payableUserId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.payableUser = user
            }.store(in: &cancelable)
    }

    func handleSaveAction(completion: @escaping () -> Void) {

    }

    func dismissPaymentFlow() {
        router?.popTo(.GroupSettleUpView(groupId: ""), inclusive: true)
    }
}

// MARK: - View States
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
