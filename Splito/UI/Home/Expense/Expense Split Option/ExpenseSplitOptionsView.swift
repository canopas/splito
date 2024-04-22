//
//  ExpenseSplitOptionsView.swift.swift
//  Splito
//
//  Created by Amisha Italiya on 22/04/24.
//

import Data
import SwiftUI
import BaseStyle

struct ExpenseSplitOptionsView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 50) {
                        Divider()
                            .frame(height: 1)
                            .background(outlineColor.opacity(0.4))

                        VStack(spacing: 8) {
                            Text("Split equally")
                                .font(.Header4())

                            Text("Select which people owe an equal share.")
                                .font(.body1())
                        }
                        .padding(.horizontal, 20)
                        .foregroundStyle(primaryText)

                        VStack(spacing: 12) {
                            ForEach(viewModel.groupMembers, id: \.self) { member in
                                ExpenseMemberCellView(member: member, isSelected: true)
                            }
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .background(backgroundColor)
        .navigationBarTitle("Split options", displayMode: .inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    viewModel.handleDoneAction {
                        dismiss()
                    }
                }
                .foregroundStyle(primaryColor)
            }
        }
    }
}

private struct ExpenseMemberCellView: View {

    @Inject var preference: SplitoPreference

    var member: AppUser
    var isSelected: Bool

    init(member: AppUser, isSelected: Bool) {
        self.member = member
        self.isSelected = isSelected
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                Text(member.fullName)
                    .font(.subTitle1())
                    .foregroundStyle(primaryText)

                Spacer()

                if isSelected {
                    Image(.checkMarkTick)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.4))
        }
    }
}

#Preview {
    ExpenseSplitOptionsView(viewModel: ExpenseSplitOptionsViewModel(amount: 0, members: [], onMemberSelection: { _ in }))
}
