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

    // MARK: - Expense Button
    case AddExpenseView

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

        case .AddExpenseView:
            "addExpenseView"

        case .AccountHomeView:
            "accountHomeView"
        }
    }
}
