//
//  ExpenseSplitOptionsTabView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/07/24.
//

import SwiftUI
import Data
import BaseStyle

struct ExpenseSplitOptionsTabView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 30) {
            HStack(spacing: 0) {
                ForEach(SplitType.allCases, id: \.self) { type in
                    Picker("", selection: $viewModel.selectedTab) {
                        Text(type.tabIcon)
                            .tag(type)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal, 12)
            }

            switch viewModel.selectedTab {
            case .equally:
                EqualShareView(viewModel: viewModel)
            case .fixedAmount:
                FixedAmountView(viewModel: viewModel)
            case .percentage:
                PercentageView(viewModel: viewModel)
            case .shares:
                ShareView(viewModel: viewModel)
            }
        }
    }
}

private struct EqualShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                ExpenseMemberCellView(member: member, isSelected: viewModel.checkIsMemberSelected(member.id)) {
                    viewModel.handleMemberSelection(member.id)
                }
            }
        }
    }
}

private struct ExpenseMemberCellView: View {

    let member: AppUser
    let isSelected: Bool

    let onTap: () -> Void

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
        .onTouchGesture(onTap)
    }
}

private struct FixedAmountView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.fixedAmounts[member.id] ?? 0 },
                        set: { viewModel.updateFixedAmount(for: member.id, amount: $0) }
                    ),
                    member: member, suffixText: "₹",
                    expenseAmount: viewModel.totalAmount,
                    onChange: { amount in
                        viewModel.updateFixedAmount(for: member.id, amount: amount)
                    }
                )
            }
        }
    }
}

private struct PercentageView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.percentages[member.id] ?? 0 },
                        set: { viewModel.updatePercentage(for: member.id, percentage: $0) }
                    ),
                    member: member, suffixText: "%",
                    totalValue: viewModel.totalPercentage,
                    expenseAmount: viewModel.totalAmount,
                    onChange: { percentage in
                        viewModel.updatePercentage(for: member.id, percentage: percentage)
                    }
                )
            }
        }
    }
}

private struct ShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.shares[member.id] ?? 0 },
                        set: { viewModel.updateShare(for: member.id, share: $0) }
                    ),
                    member: member, suffixText: "share(s)",
                    totalValue: viewModel.totalShares,
                    expenseAmount: viewModel.totalAmount,
                    onChange: { share in
                        viewModel.updateShare(for: member.id, share: share)
                    }
                )
            }
        }
    }
}

struct MemberCellView: View {

    @Binding var value: Double

    let member: AppUser
    let suffixText: String
    var totalValue: Double?
    var expenseAmount: Double

    let onChange: (Double) -> Void

    @State private var textValue: String

    init(value: Binding<Double>, member: AppUser, suffixText: String, totalValue: Double? = nil, expenseAmount: Double, onChange: @escaping (Double) -> Void) {
        self._value = value
        self.member = member
        self.suffixText = suffixText
        self.totalValue = totalValue
        self.expenseAmount = expenseAmount
        self.onChange = onChange
        self._textValue = State(initialValue: String(format: "%.0f", value.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.fullName)
                        .font(.subTitle1())
                        .foregroundStyle(primaryText)

                    if totalValue != nil {
                        let calculatedValue = totalValue == 0 ? 0 : ((expenseAmount) * (Double(value)) / (totalValue!))
                        Text((calculatedValue).formattedCurrency)
                            .font(.body2())
                            .foregroundStyle(disableText)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    TextField("0", text: $textValue, onCommit: {
                        updateValue(from: textValue)
                    })
                    .font(.subTitle1())
                    .keyboardType(.decimalPad)
                    .frame(width: 70)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text(suffixText.localized)
                        .font(.body1())
                        .foregroundStyle(primaryText)
                }
                .fixedSize()
            }
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.3))
        }
        .onChange(of: textValue) { newValue in
            updateValue(from: newValue)
        }
    }

    private func updateValue(from newValue: String) {
        if let doubleValue = Double(newValue) {
            value = doubleValue
        } else {
            value = 0
        }
        onChange(value)
    }
}
