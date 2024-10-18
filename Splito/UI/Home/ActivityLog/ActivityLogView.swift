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
                    VSpacer(16)

                    ScrollView {
                        LazyVStack(alignment: .center, spacing: 16) {
                            ForEach(viewModel.activities, id: \.id) { activity in
                                ActivityListCellView(
                                    activity: activity,
                                    description: getActivityDescription(for: activity),
                                    subDescription: getActivitySubdescription(for: activity)
                                )
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
                        Task {
                            await viewModel.fetchActivities()
                        }
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
        }
        .onAppear {
            homeRouteViewModel.updateSelectedGroup(id: nil)
        }
    }

    // Helper function to generate description for each activity
    private func getActivityDescription(for activity: ActivityLog) -> String {
        let actionUserName = activity.actionUserName
        let payerName = activity.payerName ?? "Unknown"
        let receiverName = activity.receiverName ?? "Unknown"
        let removedMemberName = activity.removedMemberName ?? "Unknown"

        switch activity.type {
        case .groupCreated, .groupDeleted:
            let type = activity.type == .groupCreated ? "created" : "deleted"
            return "\(actionUserName) \(type) the group \"\(activity.groupName)\"."
        case .groupNameUpdated:
            return "\(actionUserName) updated the group name to \"\(activity.groupName)\"."
        case .groupImageUpdated:
            return "\(actionUserName) changed the cover photo for \"\(activity.groupName)\"."
        case .groupMemberLeft:
            return actionUserName == "You" ? "\(actionUserName) removed yourself from the group \"\(activity.groupName)\"." : "\(actionUserName) left the group \"\(activity.groupName)\"."
        case .groupMemberRemoved:
            return "\(actionUserName) removed \(removedMemberName) from the group \"\(activity.groupName)\"."
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            let type = activity.type == .expenseAdded ? "added" : activity.type == .expenseUpdated ? "updated" : "deleted"
            return "\(actionUserName) \(type) \"\(activity.expenseName ?? "")\" in \"\(activity.groupName)\"."
        case .transactionAdded:
            return (actionUserName != payerName && actionUserName != receiverName) ? "\(actionUserName) added a payment from \(payerName) to \(receiverName) in \"\(activity.groupName)\"." : (actionUserName != payerName) ? "\(actionUserName) recorded a payment from \(payerName) in \"\(activity.groupName)\"." : "\(payerName) paid \(receiverName) in \"\(activity.groupName)\"."
        case .transactionUpdated, .transactionDeleted:
            let type = activity.type == .transactionUpdated ? "updated" : "deleted"
            return "\(actionUserName) \(type) a payment from \(payerName) to \(receiverName) in \"\(activity.groupName)\"."
        }
    }

    // Helper function to generate subdescription for each activity
    private func getActivitySubdescription(for activity: ActivityLog) -> String {
        switch activity.type {
        case .groupCreated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupMemberRemoved, .groupMemberLeft:
            return ""
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            return ((activity.amount ?? 0) == 0) ? "You do not owe anything" : "You \((activity.amount ?? 0) > 0 ? "get back" : "owe") \(activity.amount?.formattedCurrency ?? "0.0")"
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
            return ((activity.amount ?? 0) == 0) ? "You do not owe anything" : "You \(activity.amount ?? 0 > 0 ? "paid" : "received") \(activity.amount?.formattedCurrency ?? "0.0")"
        }
    }
}

private struct ActivityListCellView: View {

    let activity: ActivityLog
    let description: String
    let subDescription: String

    var body: some View {
        HStack(spacing: 16) {
            Image(getActivityIcon(for: activity.type))
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundStyle(primaryText)
                .padding(12)
                .background(container2Color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .font(.subTitle2())
                    .foregroundColor(primaryText)

                if !subDescription.isEmpty {
                    Text(subDescription)
                        .font(.body1())
                        .foregroundColor(secondaryText)
                }

                Text(activity.recordedOn.dateValue().dayAndTime)
                    .font(.caption)
                    .foregroundColor(disableText)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Helper function to get an appropriate icon for the activity type
    private func getActivityIcon(for type: ActivityType) -> ImageResource {
        switch type {
        case .groupCreated, .groupNameUpdated, .groupImageUpdated, .groupMemberRemoved, .groupDeleted, .groupMemberLeft:
            return .group
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            return .upArrow
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
            return .transactionIcon
        }
    }
}

private struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            Text("No Activity Available")
                .font(.subTitle1())
                .foregroundColor(primaryText)
                .padding(.bottom, 8)

            Text("Your recent activity will appear here.")
                .font(.subTitle3())
                .foregroundColor(secondaryText)

            VSpacer(60)

            Spacer()
        }
        .padding(.horizontal, 16)
        .multilineTextAlignment(.center)
    }
}
