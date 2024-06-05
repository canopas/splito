//
//  GroupPaymentViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Foundation
import Data

class GroupPaymentViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var group: Groups?
    @Published var members: [AppUser] = []
    @Published var viewState: ViewState = .initial

    @Published var showMoreOptionsSheet = false

    @Published private var expenses: [Expense] = []
    @Published var memberOwingAmount: [String: Double] = [:]

    private let groupId: String
    private var groupMemberData: [AppUser] = []
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>? = nil, groupId: String) {
        self.groupId = groupId
        self.router = router
        super.init()
    }
}

// MARK: - View States
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
