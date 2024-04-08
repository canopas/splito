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
                    .font(.Header3())
                    .foregroundColor(primaryText)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VSpacer(20)

                        UserInfoHeaderView(onTap: viewModel.openUserProfileView)
                    }
                }
            }
        }
    }
}

private struct UserInfoHeaderView: View {

    @Inject var preference: SplitoPreference

    private var userName: String {
        guard let user = preference.user else { return "" }
        return (user.firstName ?? "") + " " + (user.lastName ?? "")
    }

    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.subTitle2())
                .foregroundColor(primaryText)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 16) {
                MemberProfileImageView(imageUrl: preference.user?.imageUrl)

                VStack(alignment: .leading, spacing: 3) {
                    Text(userName)
                        .font(.subTitle1())
                        .foregroundColor(primaryText)

                    Text(preference.user?.emailId ?? "")
                        .font(.subTitle2())
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

#Preview {
    AccountHomeView(viewModel: AccountHomeViewModel(router: .init(root: .AccountHomeView)))
}
