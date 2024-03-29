//
//  ChoosePayerView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct ChoosePayerView: View {

    @ObservedObject var viewModel: ChoosePayerViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else if case .noUsers = viewModel.currentViewState {
                NoMemberFoundView()
            } else if case .hasUser(let users) = viewModel.currentViewState {
                VSpacer(10)

                Text("Choose Payer")
                    .font(.Header3())
                    .foregroundColor(.primary)

                VSpacer(10)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(users) { user in
                            MemberCellView(member: user, isSelected: user.id == viewModel.selectedPayer?.id)
                                .onTapGesture {
                                    viewModel.handlePayerSelection(user: user)
                                    dismiss()
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 30)
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
    }
}

private struct NoMemberFoundView: View {

    var body: some View {
        VStack {
            Text("No members in your selected group.")
                .font(.subTitle1())
                .foregroundColor(primaryColor)
        }
    }
}

private struct MemberCellView: View {

    @Inject var preference: SplitoPreference

    var member: AppUser
    var isSelected: Bool

    var userName: String?

    init(member: AppUser, isSelected: Bool) {
        self.member = member
        self.isSelected = isSelected
        if let user = preference.user, member.id == user.id {
            self.userName = "You"
        } else {
            self.userName = (member.firstName ?? "") + " " + (member.lastName ?? "")
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if let imageUrl = member.imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder({ _ in
                        ImageLoaderView()
                    })
                    .setProcessor(ResizingImageProcessor(referenceSize: CGSize(width: (50 * UIScreen.main.scale), height: (50 * UIScreen.main.scale)), mode: .aspectFill))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.gray, lineWidth: 1)
                    )
            } else {
                Image(.user)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.gray, lineWidth: 1)
                    )
            }

            Text((userName ?? "").isEmpty ? "Unknown" : userName!)
                .font(.subTitle2())
                .foregroundColor(primaryText)

            Spacer()

            if isSelected {
                Image(.checkMarkTick)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
        .background(backgroundColor)
    }
}

#Preview {
    ChoosePayerView(viewModel: ChoosePayerViewModel(groupId: "", selectedPayer: nil, onPayerSelection: { _ in }))
}
