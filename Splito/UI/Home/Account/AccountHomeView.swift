//
//  AccountHomeView.swift
//  Splito
//
//  Created by Amisha Italiya on 05/04/24.
//

import Data
import SwiftUI
import BaseStyle

struct AccountHomeView: View {

    @ObservedObject var viewModel: AccountHomeViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            if case .loading = viewModel.currentState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else {
                Text("Account")
                    .font(.Header4())
                    .foregroundColor(primaryText)
                    .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VSpacer(20)

                        AccountUserHeaderView(onTap: viewModel.openUserProfileView)

                        AccountFeedbackSectionView(onContactTap: viewModel.onContactUsTap,
                                                   onRateAppTap: viewModel.onRateAppTap)

                        AccountLogoutSectionView(onLogoutTap: viewModel.performLogoutAction)

                        VSpacer(20)
                    }
                }
            }
        }
        .background(backgroundColor)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toastView(toast: $viewModel.toast)
        .sheet(isPresented: $viewModel.showShareSheet) {
            MailComposeView(logFilePath: viewModel.logFilePath, showToast: viewModel.showMailSendToast)
        }
    }
}

private struct AccountUserHeaderView: View {

    @Inject var preference: SplitoPreference

    private var userName: String {
        guard let user = preference.user else { return "" }
        return (user.firstName ?? "") + " " + (user.lastName ?? "")
    }

    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.subTitle4(14))
                .foregroundColor(primaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 16) {
                MemberProfileImageView(imageUrl: preference.user?.imageUrl)

                VStack(alignment: .leading, spacing: 5) {
                    Text(userName)
                        .font(.subTitle1())
                        .foregroundColor(primaryText)

                    Text(preference.user?.emailId ?? "")
                        .font(.subTitle3())
                        .foregroundColor(secondaryText)
                }

                Spacer()

                ForwardIcon()
            }
            .padding(.horizontal, 22)
            .onTouchGesture { onTap() }

            Divider()
                .frame(height: 1)
                .background(disableLightText)
        }
    }
}

private struct AccountFeedbackSectionView: View {

    var onContactTap: () -> Void
    var onRateAppTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Feedback")
                .font(.subTitle4(14))
                .foregroundColor(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            HStack(alignment: .center, spacing: 16) {
                Text("Contact us")
                    .font(.subTitle2())
                    .foregroundColor(primaryText)

                Spacer()

                ForwardIcon()
            }
            .padding(.horizontal, 22)
            .onTouchGesture { onContactTap() }

            HStack(alignment: .center, spacing: 16) {
                Text("Rate Splito")
                    .font(.subTitle2())
                    .foregroundColor(disableText)

                Spacer()

                ForwardIcon()
            }
            .padding(.top, 10)
            .padding(.horizontal, 22)
//            .onTouchGesture { onRateAppTap() }

            Divider()
                .frame(height: 1)
                .background(disableLightText)
        }
    }
}

private struct AccountLogoutSectionView: View {

    var onLogoutTap: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Logout")
                .font(.bodyBold(18))
                .foregroundColor(primaryColor)
                .padding(.top, 30)
                .onTouchGesture { onLogoutTap() }
        }
    }
}

#Preview {
    AccountHomeView(viewModel: AccountHomeViewModel(router: .init(root: .AccountHomeView)))
}
