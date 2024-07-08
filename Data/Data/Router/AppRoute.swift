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
    case PhoneLoginView
    case VerifyOTPView(phoneNumber: String, verificationId: String)
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
    case GroupPaymentView(transactionId: String?, groupId: String, payerId: String, receiverId: String, amount: Double)
    case TransactionListView(groupId: String)
    case TransactionDetailView(transactionId: String, groupId: String)

    // MARK: - Expense Button
    case AddExpenseView(expenseId: String?, groupId: String?)
    case ExpenseDetailView(expenseId: String)
    case ChoosePayerView(groupId: String, amount: Double, selectedPayer: [String: Double], onPayerSelection: (([String: Double]) -> Void))
    case ChooseMultiplePayerView(groupId: String, amount: Double, onPayerSelection: (([String: Double]) -> Void))

    // MARK: - Activity Tab
    case ActivityHomeView

    // MARK: - Account Tab
    case AccountHomeView

    var key: String {
        switch self {
        case .OnboardView:
            "onboardView"
        case .LoginView:
            "loginView"
        case .PhoneLoginView:
            "phoneLoginView"
        case .VerifyOTPView:
            "verifyOTPView"
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
        case .ChoosePayerView:
            "choosePayerView"
        case .ChooseMultiplePayerView:
            "chooseMultiplePayerView"

        case .AccountHomeView:
            "accountHomeView"
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}
