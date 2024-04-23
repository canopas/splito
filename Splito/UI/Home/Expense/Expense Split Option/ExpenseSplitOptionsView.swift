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
                ZStack {
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
                                    ExpenseMemberCellView(member: member, isSelected: viewModel.checkIsMemberSelected(member.id)) {
                                        viewModel.handleMemberSelection(member.id)
                                    }
                                }
                            }

                            VSpacer(80)
                        }
                    }
                    .scrollIndicators(.hidden)

                    ExpenseSplitAmountView(memberCount: viewModel.selectedMembers.count, splitAmount: viewModel.splitAmount,
                                           isAllSelected: viewModel.isAllSelected, onAllBtnTap: viewModel.handleAllBtnAction)
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

    var member: AppUser
    var isSelected: Bool

    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                Text(member.fullName)
                    .font(.subTitle1())
                    .foregroundStyle(primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(successColor)
                } else {
                    Circle()
                        .strokeBorder(outlineColor.opacity(0.3), lineWidth: 1)
                        .frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.3))
        }
        .onTouchGesture {
            onTap()
        }
    }
}

private struct ExpenseSplitAmountView: View {

    var memberCount: Int
    var splitAmount: Double
    var isAllSelected: Bool

    let onAllBtnTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center) {
                Spacer()

                VStack(alignment: .center) {
                    Text("\(splitAmount.formattedCurrency)/person")
                        .font(.Header3())
                        .foregroundStyle(primaryText)
                    Text("(\(memberCount) people)")
                        .font(.body1())
                        .foregroundStyle(secondaryText)
                }
                .padding(20)

                Spacer()

                HStack(alignment: .center, spacing: 20) {
                    Divider()
                        .frame(width: 1)
                        .background(outlineColor.opacity(0.4))

                    Text("All")
                        .font(.Header3())
                        .foregroundStyle(primaryText)

                    if isAllSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(successColor)
                    } else {
                        Circle()
                            .strokeBorder(outlineColor.opacity(0.3), lineWidth: 1)
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(20)
                .onTouchGesture { onAllBtnTap() }
            }
            .frame(height: 80)
            .background(backgroundColor)
            .shadow(color: primaryText.opacity(0.1), radius: 5, x: 0, y: -5)
        }
    }
}

#Preview {
    ExpenseSplitOptionsView(viewModel: ExpenseSplitOptionsViewModel(amount: 0, members: [], selectedMembers: [], onMemberSelection: { _ in }))
}
