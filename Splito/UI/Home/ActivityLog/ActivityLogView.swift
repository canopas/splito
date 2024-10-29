//
//  ActivityLogView.swift
//  Splito
//
//  Created by Nirali Sonani on 14/10/24.
//

import SwiftUI
import BaseStyle
import Data

struct ActivityLogView: View {

    @StateObject var viewModel: ActivityLogViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchActivityLogsInitialData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
                Spacer(minLength: 60)
            } else {
                if case .noActivity = viewModel.activityLogState {
                    EmptyActivityLogView()
                } else if case .hasActivity = viewModel.activityLogState {
                    VSpacer(4)

                    ActivityLogListView(viewModel: viewModel)
                }
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast, bottomPadding: 32)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Activity")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

private struct ActivityLogListView: View {
    @EnvironmentObject var homeRouteViewModel: HomeRouteViewModel

    @ObservedObject var viewModel: ActivityLogViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .center, spacing: 0) {
                    ForEach(viewModel.filteredLogs.keys.sorted(by: viewModel.sortDayMonthYearStrings).uniqued(), id: \.self) { month in
                        Section(header: sectionHeader(month: month)) {
                            ForEach(viewModel.filteredLogs[month] ?? [], id: \.id) { activityLog in
                                ActivityListCellView(activityLog: activityLog,
                                                     isLastActivityLog: (viewModel.filteredLogs[month] ?? []).last?.id == activityLog.id,
                                                     isSelectedActivity: activityLog.id == homeRouteViewModel.activityLogId)
                                .onTapGestureForced {
                                    homeRouteViewModel.activityLogId = nil
                                    viewModel.handleActivityItemTap(activityLog)
                                }
                                .id(activityLog.id)
                            }
                        }
                    }

                    if viewModel.hasMoreLogs {
                        ProgressView()
                            .onAppear {
                                viewModel.loadMoreActivityLogs()
                            }
                    }
                }
                .padding(.bottom, 62)
            }
            .refreshable {
                viewModel.fetchActivityLogsInitialData()
            }
            .onAppear {
                scrollToActivityLogIfNeeded(using: proxy)
            }
            .onChange(of: homeRouteViewModel.activityLogId) { _ in
                scrollToActivityLogIfNeeded(using: proxy)
            }
        }
    }

    private func scrollToActivityLogIfNeeded(using proxy: ScrollViewProxy) {
        if let id = homeRouteViewModel.activityLogId {
            DispatchQueue.main.async {
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func sectionHeader(month: String) -> some View {
        var headerText: String?
        if let logDate = ActivityLogViewModel.dateFormatter.date(from: month) {
            headerText = logDate.isToday() ? "Today" : logDate.isYesterday() ? "Yesterday" : month
        }

        return Text((headerText ?? month).localized)
            .font(.subTitle1())
            .foregroundStyle(primaryText)
            .tracking(-0.2)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ActivityListCellView: View {

    let activityLog: ActivityLog
    let isLastActivityLog: Bool
    let isSelectedActivity: Bool

    var amount: Double {
        return activityLog.amount ?? 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(getActivityLogIcon())
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundStyle(primaryText)
                .padding(8)
                .background(container2Color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                ActivityLogDescriptionView(activityLog: activityLog)

                if !getLogSubdescription().isEmpty {
                    Text(getLogSubdescription().localized)
                        .font(.caption1())
                        .foregroundColor(amount > 0 ? successColor : amount < 0 ? errorColor : disableText)
                        .strikethrough(amount != 0 && (activityLog.type == .expenseDeleted || activityLog.type == .transactionDeleted))
                }

                Text(activityLog.recordedOn.dateValue().getFormattedPastTime())
                    .font(.caption1(10))
                    .foregroundColor(disableText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .center)
        .background(isSelectedActivity ? container2Color : surfaceColor)

        if !isLastActivityLog {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }

    private func getActivityLogIcon() -> ImageResource {
        switch activityLog.type {
        case .groupCreated, .groupUpdated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupRestored, .groupMemberRemoved, .groupMemberLeft:
            return .activityGroupIcon
        case .expenseAdded, .expenseUpdated, .expenseDeleted, .expenseRestored:
            return .expenseIcon
        case .transactionAdded, .transactionUpdated, .transactionDeleted, .transactionRestored:
            return .transactionIcon
        }
    }

    private func getLogSubdescription() -> String {
        switch activityLog.type {
        case .groupCreated, .groupUpdated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupRestored, .groupMemberRemoved, .groupMemberLeft:
            return ""
        case .expenseAdded, .expenseUpdated, .expenseDeleted, .expenseRestored:
            let action = (amount > 0 ? "get back" : "owe")
            return (amount == 0) ? "You do not owe anything" : "You \(action) \(amount.formattedCurrency)"
        case .transactionAdded, .transactionUpdated, .transactionDeleted, .transactionRestored:
            let action = (amount > 0 ? "paid" : "received")
            return (amount == 0) ? "You do not owe anything" : "You \(action) \(amount.formattedCurrency)"
        }
    }
}

private struct ActivityLogDescriptionView: View {

    let activityLog: ActivityLog

    let type: ActivityType
    let payerName: String
    var receiverName: String
    let groupName: String
    var oldGroupName: String
    let actionUserName: String
    var removedMemberName: String

    init(activityLog: ActivityLog) {
        self.activityLog = activityLog
        self.type = activityLog.type
        self.payerName = activityLog.payerName ?? "Someone"
        self.receiverName = activityLog.receiverName ?? "Someone"
        self.groupName = activityLog.groupName
        self.oldGroupName = activityLog.previousGroupName ?? ""
        self.actionUserName = activityLog.actionUserName
        self.removedMemberName = activityLog.removedMemberName ?? "Someone"
    }

    var body: some View {
        // Generate description for each activity log, including different color
        getActivityLogDescription()
            .font(.subTitle2())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func getActivityLogDescription() -> some View {
        switch type {
        case .groupCreated, .groupDeleted, .groupRestored:
            groupDescription()
        case .groupUpdated:
            updateGroupDescription(groupUpdated: true)
        case .groupNameUpdated:
            updateGroupDescription(groupUpdated: false)
        case .groupImageUpdated:
            actionWithGroupDescription(action: "changed the cover photo for")
        case .groupMemberLeft:
            actionWithGroupDescription(action: actionUserName == "You" ? "removed yourself from the group" : "left the group")
        case .groupMemberRemoved:
            memberRemovedDescription()
        case .expenseAdded, .expenseUpdated, .expenseDeleted, .expenseRestored:
            expenseActivityDescription()
        case .transactionAdded:
            transactionAddedDescription()
        case .transactionUpdated, .transactionDeleted, .transactionRestored:
            transactionDescription(action: (type == .transactionUpdated) ? "updated" : (type == .transactionDeleted) ? "deleted" : "restored")
        }
    }

    @ViewBuilder
    private func groupDescription() -> some View {
        let action = (type == .groupCreated) ? "created" : (type == .groupDeleted) ? "deleted" : "restored"
        actionWithGroupDescription(action: "\(action) the group")
    }

    @ViewBuilder
    private func actionWithGroupDescription(action: String) -> some View {
        highlightedText(actionUserName) + disabledText(" \(action)") + highlightedText(" \"\(groupName)\".")
    }

    @ViewBuilder
    private func updateGroupDescription(groupUpdated: Bool) -> some View {
        highlightedText(actionUserName) + disabledText(" updated the group name from") + highlightedText(" \"\(oldGroupName)\"") + disabledText(" to") +
        highlightedText(" \"\(groupName)\"") + (groupUpdated ? disabledText(" and changed the cover photo.") : disabledText("."))
    }

    @ViewBuilder
    private func memberRemovedDescription() -> some View {
        highlightedText(actionUserName) + disabledText(" removed ") + highlightedText(removedMemberName) +
        disabledText(" from the group") + highlightedText(" \"\(groupName)\".")
    }

    @ViewBuilder
    private func expenseActivityDescription() -> some View {
        let action = (type == .expenseAdded) ? "added" : (type == .expenseUpdated) ? "updated" : (type == .expenseDeleted) ? "deleted" : "restored"
        highlightedText(actionUserName) + disabledText(" \(action)") + highlightedText(" \"\(activityLog.expenseName ?? "")\"") +
        disabledText(" in") + highlightedText(" \"\(groupName)\".")
    }

    @ViewBuilder
    private func transactionAddedDescription() -> some View {
        if actionUserName != payerName && actionUserName != receiverName {
            transactionDescription()
        } else if actionUserName != payerName {
            highlightedText(actionUserName) + disabledText(" recorded a payment from ") +
            highlightedText(payerName) + disabledText(" in") + highlightedText(" \"\(groupName)\".")
        } else {
            highlightedText(payerName) + disabledText(" paid ") + highlightedText(receiverName) +
            disabledText(" in") + highlightedText(" \"\(groupName)\".")
        }
    }

    @ViewBuilder
    private func transactionDescription(action: String = "added") -> some View {
        highlightedText(actionUserName) + disabledText(" \(action) a payment from ") + highlightedText(payerName) +
        disabledText(" to ") + highlightedText(receiverName) + disabledText(" in") + highlightedText(" \"\(groupName)\".")
    }

    private func highlightedText(_ text: String) -> Text {
        Text(text.localized)
            .foregroundColor(primaryText)
    }

    private func disabledText(_ text: String) -> Text {
        Text(text.localized)
            .foregroundColor(disableText)
    }
}

private struct EmptyActivityLogView: View {

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    Image(.emptyActivityList)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 156, height: 156)
                        .padding(.bottom, 40)

                    Text("No activity yet!")
                        .font(.Header1())
                        .foregroundStyle(primaryText)
                        .padding(.bottom, 16)

                    Text("Let's get started! Add your first group and see your activities here.")
                        .font(.subTitle1())
                        .foregroundStyle(disableText)
                        .tracking(-0.2)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: geometry.size.height - 100, maxHeight: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
