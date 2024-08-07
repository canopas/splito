//
//  GroupListWithDetailView.swift
//  Splito
//
//  Created by Amisha Italiya on 24/07/24.
//

import SwiftUI
import BaseStyle

struct GroupListWithDetailView: View {

    @ObservedObject var viewModel: GroupListViewModel

    let onExpandBtnTap: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.filteredGroups.isEmpty {
                            GroupNotFoundView(geometry: geometry, viewModel: viewModel)
                        } else {
                            ForEach(viewModel.filteredGroups, id: \.group.id) { group in
                                GroupListCellView(isFirstGroup: viewModel.filteredGroups.first?.group.id == group.group.id,
                                                  isLastGroup: viewModel.filteredGroups.last?.group.id == group.group.id,
                                                  group: group, viewModel: viewModel, onExpandBtnTap: onExpandBtnTap)
                                .onTapGestureForced {
                                    viewModel.handleGroupItemTap(group.group)
                                }
                                .onLongPressGesture {
                                    viewModel.handleGroupItemTap(group.group, isTapped: false)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                    .id("groupList")
                    .background(GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .global).minY,
                                      perform: viewModel.manageScrollToTopBtnVisibility(offset:)
                            )
                    })
                }
                .scrollBounceBehavior(.basedOnSize)
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.showScrollToTopBtn {
                        ScrollToTopButton(onClick: {
                            withAnimation {
                                scrollProxy.scrollTo("groupList", anchor: .top)
                            }
                        })
                        .padding([.trailing, .bottom], 16)
                    }
                }
            }
        }
    }
}

private struct GroupListCellView: View {

    let isFirstGroup: Bool
    let isLastGroup: Bool
    let group: GroupInformation
    let viewModel: GroupListViewModel

    let onExpandBtnTap: () -> Void

    @State var showInfo: Bool = false

    init(isFirstGroup: Bool, isLastGroup: Bool = false, group: GroupInformation, viewModel: GroupListViewModel, onExpandBtnTap: @escaping () -> Void) {
        self.isFirstGroup = isFirstGroup
        self.isLastGroup = isLastGroup
        self.group = group
        self.viewModel = viewModel
        self.onExpandBtnTap = onExpandBtnTap
        self._showInfo = State(initialValue: isFirstGroup && group.oweAmount != 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                GroupProfileImageView(imageUrl: group.group.imageUrl)

                VStack(alignment: .leading, spacing: 0) {
                    Text(group.group.name)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    Text("\(group.group.members.count) people")
                        .font(.caption1())
                        .foregroundStyle(disableText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    let isBorrowed = group.oweAmount < 0
                    if group.oweAmount == 0 {
                        Text(group.hasExpenses ? "settled up" : "no expense")
                            .font(.caption1())
                            .foregroundStyle(disableText)
                    } else {
                        Text(isBorrowed ? "you owe" : "you are owed")
                            .font(.caption1())
                        Text(group.oweAmount.formattedCurrency)
                            .font(.body1())
                    }
                }
                .lineLimit(1)
                .foregroundStyle(group.oweAmount < 0 ? alertColor : successColor)

                if group.oweAmount != 0 {
                    GroupExpandBtnView(showInfo: $showInfo, isFirstGroup: isFirstGroup, onExpandBtnTap: onExpandBtnTap)
                }
            }
            .padding(.horizontal, 16)

            if showInfo {
                HStack(alignment: .top, spacing: 0) {
                    HSpacer(56) // width of image size for padding

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(group.memberOweAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                            let name = viewModel.getMemberData(from: group.members, of: memberId)?.nameWithLastInitial ?? "Unknown"
                            GroupExpenseMemberOweView(name: name, amount: amount)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 24)

        if !isLastGroup {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }
}

private struct GroupExpandBtnView: View {

    @Binding var showInfo: Bool

    let isFirstGroup: Bool
    let onExpandBtnTap: () -> Void

    var body: some View {
        ScrollToTopButton(icon: "chevron.down", iconColor: primaryText, bgColor: container2Color, showWithAnimation: true, size: (10, 7), isFirstGroupCell: isFirstGroup, onClick: {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                showInfo.toggle()
            }
            onExpandBtnTap()
        })
        .onAppear {
            if isFirstGroup {
                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                    showInfo = true
                }
            }
        }
        .padding(.leading, 8)
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double

    var body: some View {
        if amount > 0 {
            Group {
                Text("\(name.localized) owes you ")
                    .foregroundColor(disableText)
                + Text("\(amount.formattedCurrency)")
                    .foregroundColor(successColor)
            }
            .font(.body3())
        } else if amount < 0 {
            Group {
                Text("You owe \(name.localized) ")
                    .foregroundColor(disableText)
                + Text("\(amount.formattedCurrency)")
                    .foregroundColor(alertColor)
            }
            .font(.body3())
        }
    }
}

private struct GroupNotFoundView: View {

    let geometry: GeometryProxy
    let viewModel: GroupListViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            if !viewModel.showSearchBar {
                Image(viewModel.selectedTab == .settled ? .settleUpGroup : .unsettledGroup)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 165, height: 165)
            }

            Text(viewModel.showSearchBar ? "No results found for \"\(viewModel.searchedGroup)\"!" : viewModel.selectedTab == .settled ? "No groups settled yet!" : "No unsettled bills yet!")
                .font(.Header1())
                .foregroundColor(primaryText)

            Text(viewModel.showSearchBar ? "No results were found that match your search criteria." : viewModel.selectedTab == .settled ? "Looks like there are no outstanding settlements in any of your groups yet." : "It seems that everything has settled down in all groups.")
                .font(.subTitle2())
                .foregroundColor(disableText)
                .tracking(-0.2)
                .lineSpacing(4)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: geometry.size.height - 70, maxHeight: .infinity, alignment: .center)
    }
}
