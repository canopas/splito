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
    @EnvironmentObject var homeRouteViewModel: HomeRouteViewModel

    @StateObject var viewModel: ActivityLogViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchActivitiesInitialData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
                Spacer(minLength: 60)
            } else {
                if case .noActivity = viewModel.activityListState {
                    EmptyActivityView()
                } else if case .hasActivity = viewModel.activityListState {
                    VSpacer(4)

                    ScrollView {
                        LazyVStack(alignment: .center, spacing: 0) {
                            ForEach(viewModel.activities, id: \.id) { activity in
                                ActivityListCellView(activity: activity,
                                                     isLastActivity: viewModel.activities.last?.id == activity.id)
                                .onTapGestureForced {
                                    viewModel.handleActivityItemTap(activity)
                                }

                                if activity.id == viewModel.activities.last?.id && viewModel.hasMoreActivities {
                                    ProgressView()
                                        .onAppear {
                                            viewModel.loadMoreActivities()
                                        }
                                }
                            }

                            VSpacer(10)
                        }
                        .padding(.bottom, 62)
                    }
                    .refreshable {
                        viewModel.fetchActivitiesInitialData()
                    }
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast, bottomPadding: 32)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Activity")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("Delete")
                    .font(.subTitle3())
                    .foregroundStyle(disableText)
                    .onTapGesture(perform: viewModel.deleteAllActivities)
            }
        }
        .onAppear {
            homeRouteViewModel.updateSelectedGroup(id: nil)
        }
    }
}

private struct ActivityListCellView: View {

    let activity: ActivityLog
    let isLastActivity: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(getActivityIcon(for: activity.type))
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundStyle(primaryText)
                .padding(8)
                .background(container2Color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                getActivityDescription()
                    .font(.subTitle2())

                if !getActivitySubdescription().isEmpty {
                    Text(getActivitySubdescription())
                        .font(.caption1())
                        .foregroundColor((activity.amount ?? 0) > 0 ? successColor : errorColor)
                        .strikethrough(activity.type == .expenseDeleted || activity.type == .transactionDeleted)
                }

                Text(activity.recordedOn.dateValue().getFormatedPastTime())
                    .font(.caption1(10))
                    .foregroundColor(disableText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)

        if !isLastActivity {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }

    // Helper function to generate description for each activity, including different color
    @ViewBuilder
    private func getActivityDescription() -> some View {
        let actionUserName = activity.actionUserName
        let payerName = activity.payerName ?? "Someone"
        let receiverName = activity.receiverName ?? "Someone"
        let removedMemberName = activity.removedMemberName ?? "Someone"
        let oldGroupName = activity.previousGroupName ?? ""

        switch activity.type {
        case .groupCreated, .groupDeleted:
            let type = activity.type == .groupCreated ? "created" : "deleted"
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(" \(type) the group")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)

        case .groupUpdated:
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(" updated the group name")
                .foregroundColor(disableText) +
            Text(" \"\(oldGroupName)\"")
                .foregroundColor(primaryText) +
            Text(" to")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\"")
                .foregroundColor(primaryText) +
            Text(" and")
                .foregroundColor(disableText) +
            Text(" changed the cover photo.")
                .foregroundColor(disableText)

        case .groupNameUpdated:
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(" updated the group name")
                .foregroundColor(disableText) +
            Text(" \"\(oldGroupName)\"")
                .foregroundColor(primaryText) +
            Text(" to")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)

        case .groupImageUpdated:
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(" changed the cover photo for")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)

        case .groupMemberLeft:
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(actionUserName == "You" ? " removed yourself from the group" : " left the group")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)

        case .groupMemberRemoved:
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(" removed ")
                .foregroundColor(disableText) +
            Text(removedMemberName)
                .foregroundColor(primaryText) +
            Text(" from the group")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)

        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            let type = activity.type == .expenseAdded ? " added" : activity.type == .expenseUpdated ? " updated" : " deleted"
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(type)
                .foregroundColor(disableText) +
            Text(" \"\(activity.expenseName ?? "")\"")
                .foregroundColor(primaryText) +
            Text(" in")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)

        case .transactionAdded:
            if actionUserName != payerName && actionUserName != receiverName {
                Text(actionUserName)
                    .foregroundColor(primaryText) +
                Text(" added a payment from ")
                    .foregroundColor(disableText) +
                Text(payerName)
                    .foregroundColor(primaryText) +
                Text(" to ")
                    .foregroundColor(disableText) +
                Text(receiverName)
                    .foregroundColor(primaryText) +
                Text(" in")
                    .foregroundColor(disableText) +
                Text(" \"\(activity.groupName)\".")
                    .foregroundColor(primaryText)
            } else if actionUserName != payerName {
                Text(actionUserName)
                    .foregroundColor(primaryText) +
                Text(" recorded a payment from ")
                    .foregroundColor(disableText) +
                Text(payerName)
                    .foregroundColor(successColor) +
                Text(" in")
                    .foregroundColor(disableText) +
                Text(" \"\(activity.groupName)\".")
                    .foregroundColor(primaryText)
            } else {
                Text(payerName)
                    .foregroundColor(primaryText) +
                Text(" paid ")
                    .foregroundColor(disableText) +
                Text(receiverName)
                    .foregroundColor(primaryText) +
                Text(" in")
                    .foregroundColor(disableText) +
                Text(" \"\(activity.groupName)\".")
                    .foregroundColor(primaryText)
            }

        case .transactionUpdated, .transactionDeleted:
            let type = activity.type == .transactionUpdated ? "updated" : "deleted"
            Text(actionUserName)
                .foregroundColor(primaryText) +
            Text(" \(type) a payment from ")
                .foregroundColor(disableText) +
            Text(payerName)
                .foregroundColor(primaryText) +
            Text(" to ")
                .foregroundColor(disableText) +
            Text(receiverName)
                .foregroundColor(primaryText) +
            Text(" in")
                .foregroundColor(disableText) +
            Text(" \"\(activity.groupName)\".")
                .foregroundColor(primaryText)
        }
    }

    private func getActivitySubdescription() -> String {
        switch activity.type {
        case .groupCreated, .groupUpdated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupMemberRemoved, .groupMemberLeft:
            return ""
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            return ((activity.amount ?? 0) == 0) ? "You do not owe anything" : "You \((activity.amount ?? 0) > 0 ? "get back" : "owe") \(activity.amount?.formattedCurrency ?? "0.0")"
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
            return ((activity.amount ?? 0) == 0) ? "You do not owe anything" : "You \(activity.amount ?? 0 > 0 ? "paid" : "received") \(activity.amount?.formattedCurrency ?? "0.0")"
        }
    }

    private func getActivityIcon(for type: ActivityType) -> ImageResource {
        switch type {
        case .groupCreated, .groupUpdated, .groupNameUpdated, .groupImageUpdated, .groupMemberRemoved, .groupDeleted, .groupMemberLeft:
            return .activityGroupIcon
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            return .expenseIcon
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
            return .transactionIcon
        }
    }
}

private struct EmptyActivityView: View {

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

                    Text("Let's get started! Add your first expense and see your activity here.")
                        .font(.subTitle1())
                        .foregroundStyle(disableText)
                        .tracking(-0.2)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: geometry.size.height - 100, maxHeight: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
