//
//  ActivityLogViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/10/24.
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
    private var task: Task<Void, Never>?  // Reference to the current asynchronous task that fetches logs

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter
    }()

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        self.fetchInitialActivityLogs()
        self.fetchLatestActivityLogs()
    }

    deinit {
        task?.cancel()
    }

    func fetchInitialActivityLogs(needToReload: Bool = false) {
        lastDocument = nil
        Task {
            await fetchActivityLogs(needToReload: needToReload)
        }
    }

    // MARK: - Data Loading
    private func fetchActivityLogs(needToReload: Bool = false) async {
        guard let userId = preference.user?.id, hasMoreLogs || needToReload else {
            viewState = .initial
            return
        }

        do {
            let result = try await activityLogRepository.fetchActivitiesBy(userId: userId, limit: ACTIVITY_LOG_LIMIT,
                                                                           lastDocument: lastDocument)
            activityLogs = lastDocument == nil ? result.data : (activityLogs + result.data)
            hasMoreLogs = !(result.data.count < ACTIVITY_LOG_LIMIT)
            lastDocument = result.lastDocument

            filterActivityLogs()
            viewState = .initial
            activityLogState = activityLogs.isEmpty ? .noActivity : .hasActivity
            LogD("ActivityLogViewModel: \(#function) Activity logs fetched successfully.")
        } catch {
            LogE("ActivityLogViewModel: \(#function) Failed to fetch activity logs: \(error).")
            handleServiceError()
        }
    }

    func loadMoreActivityLogs() {
        Task {
            await fetchActivityLogs()
        }
    }

    // Listens real-time updates and returns the latest activity logs for the current user
    private func fetchLatestActivityLogs() {
        guard let userId = preference.user?.id else { return }

        task?.cancel()  // Cancel the existing task if it's running
        task = Task { [unowned self] in
            let activityLogStream = activityLogRepository.fetchLatestActivityLogs(userId: userId)
            for await activityLogs in activityLogStream {
                guard !Task.isCancelled else { return } // Exit early if the task is cancelled

                if let activityLogs {
                    for activityLog in activityLogs where !(self.activityLogs.contains(where: { $0.id == activityLog.id })) {
                        self.activityLogs.append(activityLog)
                    }
                    filterActivityLogs()
                    if self.activityLogs.count == 1 {
                        activityLogState = .hasActivity
                    } else if self.activityLogs.count < 1 {
                        activityLogState = .noActivity
                    }
                } else {
                    self.showToastForError()
                }
            }
        }
    }

    private func filterActivityLogs() {
        let sortedActivities = activityLogs.uniqued().sorted { $0.recordedOn.dateValue() > $1.recordedOn.dateValue() }
        filteredLogs = Dictionary(grouping: sortedActivities) { log in
            if log.recordedOn.dateValue().isCurrentMonth() {
                return ActivityLogViewModel.dateFormatter.string(from: log.recordedOn.dateValue()) // day-wise format
            } else {
                return log.recordedOn.dateValue().monthWithYear // month-year format
            }
        }
    }

    // MARK: - User Actions
    func handleActivityItemTap(_ activity: ActivityLog) {
        switch activity.type {
        case .groupCreated, .groupUpdated, .groupNameUpdated, .groupImageUpdated, .groupDeleted, .groupRestored:
            router.push(.GroupHomeView(groupId: activity.activityId))
        case .groupMemberRemoved, .groupMemberLeft, .none:
            break
        case .expenseAdded, .expenseUpdated, .expenseDeleted, .expenseRestored:
            router.push(.ExpenseDetailView(groupId: activity.groupId, expenseId: activity.activityId))
        case .transactionAdded, .transactionUpdated, .transactionDeleted, .transactionRestored:
            router.push(.TransactionDetailView(transactionId: activity.activityId, groupId: activity.groupId))
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if lastDocument == nil {
            if !networkMonitor.isConnected {
                viewState = .noInternet
            } else {
                viewState = .somethingWentWrong
            }
        } else {
            viewState = .initial
            showToastForError()
        }
    }

    // MARK: - Helpor Methods
    func sortKeysByDayAndMonth() -> [String] {
        let dayKeys = filteredLogs.keys.filter { ActivityLogViewModel.dateFormatter.date(from: $0) != nil }
        let monthYearKeys = filteredLogs.keys.filter { ActivityLogViewModel.dateFormatter.date(from: $0) == nil }

        let sortedDayKeys = dayKeys.sorted(by: sortDayMonthYearStrings)
        let sortedMonthYearKeys = monthYearKeys.sorted(by: sortMonthYearStrings)

        return (sortedDayKeys + sortedMonthYearKeys)  // Concatenate for final sorted order
    }

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
