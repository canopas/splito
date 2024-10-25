//
//  ActivityLogViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 14/10/24.
//

import FirebaseFirestore
import Data

class ActivityLogViewModel: BaseViewModel, ObservableObject {

    private let ACTIVITY_LOG_LIMIT = 20

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var activityLogRepository: ActivityLogRepository

    @Published private(set) var viewState: ViewState = .loading
    @Published private(set) var activityLogState: ActivityLogState = .noActivity

    @Published private(set) var activityLogs: [ActivityLog] = []
    @Published private(set) var filteredLogs: [String: [ActivityLog]] = [:]

    @Published private(set) var hasMoreLogs: Bool = true

    private let router: Router<AppRoute>
    private var lastDocument: DocumentSnapshot?

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter
    }()

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        self.fetchActivityLogsInitialData()
        self.fetchLatestActivityLogs()
    }

    func fetchActivityLogsInitialData() {
        Task {
            await fetchActivityLogs()
        }
    }

    // MARK: - Data Loading
    private func fetchActivityLogs() async {
        guard let userId = preference.user?.id else {
            viewState = .initial
            return
        }

        do {
            viewState = .loading
            let result = try await activityLogRepository.fetchActivitiesBy(userId: userId, limit: ACTIVITY_LOG_LIMIT)

            activityLogs = result.data
            lastDocument = result.lastDocument
            hasMoreLogs = !(result.data.count < ACTIVITY_LOG_LIMIT)

            filterActivityLogs()
            viewState = .initial
            activityLogState = activityLogs.isEmpty ? .noActivity : .hasActivity
        } catch {
            handleServiceError()
        }
    }

    func loadMoreActivityLogs() {
        Task {
            await fetchMoreActivityLogs()
        }
    }

    private func fetchMoreActivityLogs() async {
        guard hasMoreLogs, let userId = preference.user?.id else { return }

        do {
            let result = try await activityLogRepository.fetchActivitiesBy(userId: userId, limit: ACTIVITY_LOG_LIMIT, lastDocument: lastDocument)

            activityLogs.append(contentsOf: result.data)
            lastDocument = result.lastDocument
            hasMoreLogs = !(result.data.count < ACTIVITY_LOG_LIMIT)

            filterActivityLogs()
            viewState = .initial
            activityLogState = activityLogs.isEmpty ? .noActivity : .hasActivity
        } catch {
            viewState = .initial
            showToastForError()
        }
    }

    private func filterActivityLogs() {
        let sortedActivities = activityLogs.uniqued().sorted { $0.recordedOn.dateValue() > $1.recordedOn.dateValue() }
        filteredLogs = Dictionary(grouping: sortedActivities) { log in
            let formattedDate = ActivityLogViewModel.dateFormatter.string(from: log.recordedOn.dateValue())
            return formattedDate
        }
    }

    // Listens for real-time updates and returns the latest activity logs for the current user
    private func fetchLatestActivityLogs() {
        guard let userId = preference.user?.id else {
            viewState = .initial
            return
        }

        activityLogRepository.fetchLatestActivityLogs(userId: userId) { [weak self] activityLogs in
            if let activityLogs {
                for activityLog in activityLogs where !(self?.activityLogs.contains(where: { $0.id == activityLog.id }) ?? false) {
                    self?.activityLogs.append(activityLog)
                }
                self?.filterActivityLogs()
            } else {
                self?.showToastForError()
            }
        }
    }

    // MARK: - User Actions
    func handleActivityItemTap(_ activity: ActivityLog) {
        switch activity.type {
        case .groupCreated, .groupUpdated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupRestored:
            router.push(.GroupHomeView(groupId: activity.activityId))
        case .groupMemberRemoved, .groupMemberLeft:
            break
        case .expenseAdded, .expenseUpdated, .expenseDeleted, .expenseRestored:
            router.push(.ExpenseDetailView(groupId: activity.groupId, expenseId: activity.activityId))
        case .transactionAdded, .transactionUpdated, .transactionDeleted, .transactionRestored:
            router.push(.TransactionDetailView(transactionId: activity.activityId, groupId: activity.groupId))
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            viewState = .noInternet
        } else {
            viewState = .somethingWentWrong
        }
    }

    // MARK: - Helpor Methods
    func sortDayMonthYearStrings(_ s1: String, _ s2: String) -> Bool {
        guard let date1 = ActivityLogViewModel.dateFormatter.date(from: s1),
              let date2 = ActivityLogViewModel.dateFormatter.date(from: s2) else {
            return false
        }

        return date1 > date2
    }
}

// MARK: - Group States
extension ActivityLogViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }

    enum ActivityLogState {
        case noActivity
        case hasActivity
    }
}
