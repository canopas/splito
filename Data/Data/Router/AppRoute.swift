//
//  AppRoute.swift
//  Data
//
//  Created by Amisha Italiya on 27/02/24.
//

import Foundation

public enum AppRoute: Hashable {

    public static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        return lhs.key == rhs.key
    }

    case OnboardView
    case LoginView
    case EmailLoginView(onDismiss: (() -> Void)? = nil)
    case ProfileView
    case HomeView

    // MARK: - Friends Tab
    case FriendsHomeView

    // MARK: - Groups Tab
    case GroupListView
    case GroupHomeView(groupId: String)
    case CreateGroupView(group: Groups?)
    case InviteMemberView(groupId: String)
    case JoinMemberView
    case GroupSettingView(groupId: String)
    case GroupSettleUpView(groupId: String)
    case GroupWhoIsPayingView(groupId: String, isPaymentSettled: Bool)
    case GroupWhoGettingPaidView(groupId: String, selectedMemberId: String)
    case GroupPaymentView(transactionId: String?, groupId: String, payerId: String, receiverId: String,
                          amount: Double, currency: String)
    case TransactionListView(groupId: String)
    case TransactionDetailView(transactionId: String, groupId: String)

    // MARK: - Expense Button
    case AddExpenseView(groupId: String, expenseId: String?)
    case ExpenseDetailView(groupId: String, expenseId: String)
    case ChoosePayerView(groupId: String, amount: Double, currency: String, selectedPayer: [String: Double],
                         onPayerSelection: (([String: Double]) -> Void))
    case ChooseMultiplePayerView(groupId: String, selectedPayers: [String: Double], amount: Double,
                                 currency: String, onPayerSelection: (([String: Double]) -> Void))

    // MARK: - Activity Tab
    case ActivityHomeView
    case ExpensesSearchView

    // MARK: - Account Tab
    case AccountHomeView
    case FeedbackView

    var key: String {
        switch self {
        case .OnboardView:
            "onboardView"
        case .LoginView:
            "loginView"
        case .EmailLoginView:
            "EmailLoginView"
        case .ProfileView:
            "userProfileView"
        case .HomeView:
            "homeView"

        case .FriendsHomeView:
            "friendsHomeView"

        case .ActivityHomeView:
            "activityHomeView"
        case .ExpenseDetailView:
            "expenseDetailView"

        case .GroupListView:
            "groupListView"
        case .GroupHomeView:
            "groupHomeView"
        case .CreateGroupView:
            "createGroupView"
        case .InviteMemberView:
            "inviteMemberView"
        case .JoinMemberView:
            "joinMemberView"
        case .GroupSettingView:
            "groupSettingView"
        case .GroupSettleUpView:
            "groupSettleUpView"
        case .GroupWhoIsPayingView:
            "groupWhoIsPayingView"
        case .GroupWhoGettingPaidView:
            "groupWhoGettingPaidView"
        case .GroupPaymentView:
            "groupPaymentView"
        case .TransactionListView:
            "transactionListView"
        case .TransactionDetailView:
            "transactionDetailView"

        case .AddExpenseView:
            "addExpenseView"
        case .ExpensesSearchView:
            "expensesSearchView"

        case .ChoosePayerView:
            "choosePayerView"
        case .ChooseMultiplePayerView:
            "chooseMultiplePayerView"

        case .AccountHomeView:
            "accountHomeView"
        case .FeedbackView:
            "feedbackView"
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}
