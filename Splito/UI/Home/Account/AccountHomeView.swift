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
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.currentState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        AccountUserHeaderView(user: viewModel.preference.user, onTap: viewModel.openUserProfileView)

                        Divider()
                            .frame(height: 1)
                            .background(dividerColor)

                        AccountStayInTouchSectionView(onContactTap: viewModel.onContactSupportTap,
                                                      onRateAppTap: viewModel.onRateAppTap,
                                                      onShareAppTap: viewModel.onShareAppTap)

                        Divider()
                            .frame(height: 1)
                            .background(dividerColor)

                        AccountAboutSectionView(onPrivacyTap: viewModel.handlePrivacyOptionTap,
                                                onAcknowledgementsTap: viewModel.handleAcknowledgementsOptionTap,
                                                onLogoutTap: viewModel.handleLogoutBtnTap)

                        VSpacer(20)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Account")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showShareAppSheet) {
            ShareSheetView(activityItems: [Constants.shareAppURL]) { isCompleted in
                if isCompleted {
                    viewModel.dismissShareAppSheet()
                }
            }
        }
    }
}

private struct AccountUserHeaderView: View {

    let user: AppUser?
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MemberProfileImageView(imageUrl: user?.imageUrl, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(user?.fullName ?? "")
                    .font(.Header3())
                    .foregroundStyle(primaryText)

                if user?.emailId != nil && !(user?.emailId?.isEmpty ?? false) {
                    Text(user?.emailId ?? "")
                        .font(.body3())
                        .foregroundStyle(disableText)
                }
            }

            Spacer()

            ForwardIcon()
        }
        .padding(16)
        .onTouchGesture(onTap)
        .background(container2Color)
        .cornerRadius(12)
        .padding([.horizontal, .top], 16)
    }
}

private struct AccountStayInTouchSectionView: View {

    let onContactTap: () -> Void
    let onRateAppTap: () -> Void
    let onShareAppTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Stay In Touch")
                .font(.Header4())
                .foregroundStyle(primaryText)

            VSpacer(16)

            AccountItemCellView(optionText: "Contact Support", onClick: onContactTap)

            AccountItemCellView(optionText: "Rate Splito", onClick: onRateAppTap)

            AccountItemCellView(optionText: "Share App", onClick: onShareAppTap)
        }
        .padding(.horizontal, 16)
    }
}

private struct AccountAboutSectionView: View {

    let onPrivacyTap: () -> Void
    let onAcknowledgementsTap: () -> Void
    let onLogoutTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("About")
                .font(.Header4())
                .foregroundStyle(primaryText)

            VSpacer(16)

            AccountItemCellView(optionText: "Privacy Policy", onClick: onPrivacyTap)

            AccountItemCellView(optionText: "Acknowledgements", onClick: onAcknowledgementsTap)

            AccountItemCellView(optionText: "Sign Out", optionTextColor: errorColor, showForwardIcon: false, onClick: onLogoutTap)
        }
        .padding(.horizontal, 16)
    }
}

private struct AccountItemCellView: View {

    let optionText: String
    var optionTextColor: Color = primaryText
    var showForwardIcon: Bool = true

    var onClick: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(optionText.localized)
                .font(.subTitle2())
                .foregroundStyle(optionTextColor)

            Spacer()

            if showForwardIcon {
                ForwardIcon()
            }
        }
        .padding(.vertical, 12)
        .onTouchGesture(onClick)
    }
}
