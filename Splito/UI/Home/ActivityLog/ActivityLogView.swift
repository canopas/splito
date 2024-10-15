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
                                ActivityListCellView(activity: activity)
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
                Text("Recent activity")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
        .onAppear {
            homeRouteViewModel.updateSelectedGroup(id: nil)
        }
    }
}

private struct ActivityListCellView: View {

    let activity: ActivityLog

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
                Text(getActivityDescription(for: activity))
                    .font(.subTitle2())
                    .foregroundColor(primaryText)

                Text(getActivitySubdescription(for: activity))
                    .font(.body1())
                    .foregroundColor(secondaryText)

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
        case .groupCreated, .groupNameUpdated, .groupImageUpdated, .groupMemberRemoved, .groupDeleted:
            return .group
        case .expenseAdded:
            return .upArrow
        case .expenseUpdated:
            return .upArrow
        case .expenseDeleted:
            return .upArrow
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
            return .transactionIcon
        }
    }

    // Helper function to generate description for each activity
    private func getActivityDescription(for activity: ActivityLog) -> String {
        switch activity.type {
        case .groupCreated:
            return "\(activity.actionUserName) created the group \"\(activity.groupName)\"."
        case .groupNameUpdated, .groupImageUpdated, .groupMemberRemoved:
            return "\(activity.actionUserName) changed the cover photo for \"\(activity.groupName)\"."
        case .groupDeleted:
            return "\(activity.actionUserName) deleted the group \"\(activity.groupName)\"."
        case .expenseAdded:
            return "\(activity.actionUserName) added \"\(activity.expenseName ?? "")\" in \"\(activity.groupName)\"."
        case .expenseUpdated:
            return "\(activity.actionUserName) updated \"\(activity.expenseName ?? "")\" in \"\(activity.groupName)\"."
        case .expenseDeleted:
            return "\(activity.actionUserName) deleted \"\(activity.expenseName ?? "")\" in \"\(activity.groupName)\"."
        case .transactionAdded:
            return "\(activity.payerName ?? "") paid \(activity.receiverName ?? "") in \"\(activity.groupName)\"."
        case .transactionUpdated:
            return "\(activity.actionUserName) updated a payment from \(activity.payerName ?? "") to \(activity.receiverName ?? "") in \"\(activity.groupName)\"."
        case .transactionDeleted:
            return "\(activity.actionUserName) deleted a payment from \(activity.payerName ?? "") to \(activity.receiverName ?? "") in \"\(activity.groupName)\"."
        }
    }

    // Helper function to generate subdescription for each activity
    private func getActivitySubdescription(for activity: ActivityLog) -> String {
        switch activity.type {
        case .groupCreated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupMemberRemoved:
            return ""
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            return ((activity.amount ?? 0) == 0) ? "You do not owe anything" : "You \((activity.amount ?? 0) > 0 ? "get back" : "owe") \(activity.amount?.formattedCurrency ?? "0.0")"
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
            return "\(activity.amount ?? 0 > 0 ? activity.payerName ?? "" : activity.receiverName ?? "") \(activity.amount ?? 0 > 0 ? "paid" : "received") \(activity.amount?.formattedCurrency ?? "0.0")"
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
