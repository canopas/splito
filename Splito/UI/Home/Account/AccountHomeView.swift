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
                LoaderView()
            } else {
                Text("Account")
                    .font(.Header4())
                    .foregroundStyle(primaryText)
                    .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 20) {
                        VSpacer(20)

                        AccountUserHeaderView(onTap: viewModel.openUserProfileView)

                        AccountFeedbackSectionView(onContactTap: viewModel.onContactUsTap,
                                                   onRateAppTap: viewModel.onRateAppTap)

                        AccountLogoutSectionView(onLogoutTap: viewModel.handleLogoutBtnTap)

                        VSpacer(20)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showShareSheet) {
            MailComposeView(logFilePath: viewModel.logFilePath, showToast: viewModel.showMailSendToast)
        }
    }
}

private struct AccountUserHeaderView: View {

    @Inject var preference: SplitoPreference

    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.subTitle4(14))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 16) {
                MemberProfileImageView(imageUrl: preference.user?.imageUrl)

                VStack(alignment: .leading, spacing: 5) {
                    Text(preference.user?.fullName ?? "")
                        .font(.subTitle1())
                        .foregroundStyle(primaryText)

                    Text(preference.user?.emailId ?? "")
                        .font(.subTitle3())
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                ForwardIcon()
            }
            .padding(.horizontal, 22)
            .onTouchGesture { onTap() }

            Divider()
                .frame(height: 1)
                .background(outlineColor)
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
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            HStack(alignment: .center, spacing: 16) {
                Text("Contact us")
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)

                Spacer()

                ForwardIcon()
            }
            .padding(.horizontal, 22)
            .onTouchGesture { onContactTap() }

            HStack(alignment: .center, spacing: 16) {
                Text("Rate Splito")
                    .font(.subTitle2())
                    .foregroundStyle(disableText)

                Spacer()

                ForwardIcon()
            }
            .padding(.top, 10)
            .padding(.horizontal, 22)
//            .onTouchGesture { onRateAppTap() }

            Divider()
                .frame(height: 1)
                .background(outlineColor)
        }
    }
}

private struct AccountLogoutSectionView: View {

    var onLogoutTap: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Sign out")
                .font(.bodyBold(18))
                .foregroundStyle(primaryColor)
                .padding(.top, 30)
                .onTouchGesture { onLogoutTap() }
        }
    }
}

#Preview {
    AccountHomeView(viewModel: AccountHomeViewModel(router: .init(root: .AccountHomeView)))
}
