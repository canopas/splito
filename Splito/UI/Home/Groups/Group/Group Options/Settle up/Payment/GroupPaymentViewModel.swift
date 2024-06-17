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
    @Inject private var transactionRepository: TransactionRepository

    @Published var amount: Double = 0
    @Published var paymentDate = Date()

    @Published var payer: AppUser?
    @Published var receiver: AppUser?
    @Published var viewState: ViewState = .initial

    let payerId: String
    let receiverId: String
    private let groupId: String
    private let router: Router<AppRoute>?

    var dismissPaymentFlow: () -> Void

    init(router: Router<AppRoute>, groupId: String, payerId: String, receiverId: String, amount: Double, dismissPaymentFlow: @escaping () -> Void) {
        self.router = router
        self.groupId = groupId
        self.payerId = payerId
        self.receiverId = receiverId
        self.amount = abs(amount)
        self.dismissPaymentFlow = dismissPaymentFlow
        super.init()

        getPayerUserDetail()
        getPayableUserDetail()
    }

    private func getPayerUserDetail() {
        userRepository.fetchUserBy(userID: payerId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.payer = user
            }.store(in: &cancelable)
    }

    private func getPayableUserDetail() {
        userRepository.fetchUserBy(userID: receiverId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.receiver = user
            }.store(in: &cancelable)
    }

    func handleSaveAction(completion: @escaping () -> Void) {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "You must enter an amount.")
            return
        }
        guard let userId = preference.user?.id else { return }

        let transaction = Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                       groupId: groupId, amount: amount, date: .init(date: paymentDate))

        viewState = .loading
        transactionRepository.addTransaction(transaction: transaction)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.dismissPaymentFlow()
                self?.viewState = .initial
            }.store(in: &cancelable)
    }
}

// MARK: - View States
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
