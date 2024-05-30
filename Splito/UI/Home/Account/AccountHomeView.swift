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

    @StateObject var viewModel: AccountHomeViewModel

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

                        AccountUserHeaderView(user: viewModel.preference.user, onTap: viewModel.openUserProfileView)

                        AccountFeedbackSectionView(onContactTap: viewModel.onContactUsTap,
                                                   onRateAppTap: viewModel.onRateAppTap,
                                                   onShareAppTap: viewModel.onShareAppTap)

                        AccountAboutSectionView(onPrivacyTap: viewModel.handlePrivacyOptionTap, onAcknowledgementsTap: viewModel.handleAcknowledgementsOptionTap)

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
        .sheet(isPresented: $viewModel.showShareAppSheet) {
            ShareSheetView(activityItems: [Constants.shareAppURL])
        }
    }
}

private struct AccountUserHeaderView: View {

    let user: AppUser?
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.subTitle4(14))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)

            HStack(alignment: .center, spacing: 16) {
                MemberProfileImageView(imageUrl: user?.imageUrl)

                VStack(alignment: .leading, spacing: 5) {
                    Text(user?.fullName ?? "")
                        .font(.subTitle1())
                        .foregroundStyle(primaryText)

                    Text(user?.emailId ?? "")
                        .font(.subTitle3())
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                ForwardIcon()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onTouchGesture { onTap() }
            .background(containerLowColor)
            .cornerRadius(16)
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(outlineColor)
        }
    }
}

private struct AccountFeedbackSectionView: View {

    var onContactTap: () -> Void
    var onRateAppTap: () -> Void
    var onShareAppTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stay In Touch")
                .font(.subTitle4(14))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            AccountItemCellView(optionText: "Contact us", onClick: onContactTap)

            AccountItemCellView(optionText: "Rate Splito", onClick: onRateAppTap)
                .padding(.top, 10)

            AccountItemCellView(optionText: "Share app", onClick: onShareAppTap)
                .padding(.top, 10)

            Divider()
                .frame(height: 1)
                .background(outlineColor)
        }
    }
}

private struct AccountAboutSectionView: View {

    var onPrivacyTap: () -> Void
    var onAcknowledgementsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.subTitle4(14))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            AccountItemCellView(optionText: "Privacy", onClick: onPrivacyTap)

            AccountItemCellView(optionText: "Acknowledgements", onClick: onAcknowledgementsTap)
                .padding(.top, 10)

            Divider()
                .frame(height: 1)
                .background(outlineColor)
        }
    }
}

private struct AccountItemCellView: View {

    let optionText: String
    var onClick: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(optionText)
                .font(.subTitle2())
                .foregroundStyle(primaryText)

            Spacer()

            ForwardIcon()
        }
        .padding(.horizontal, 22)
        .onTouchGesture(onClick)
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
