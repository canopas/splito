//
//  ActivityLogViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 14/10/24.
//

import FirebaseFirestore
import Data

class ActivityLogViewModel: BaseViewModel, ObservableObject {

    private let ACTIVITIES_LIMIT = 10

    @Inject var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var activityRepository: ActivityRepository

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var activityListState: ActivityListState = .noActivity

    @Published private(set) var activities: [ActivityLog] = []
    @Published private(set) var groupMemberData: [AppUser] = []

    @Published private(set) var hasMoreActivities: Bool = true

    private let router: Router<AppRoute>
    private var lastDocument: DocumentSnapshot?

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        self.fetchActivitiesInitialData()
    }

    func fetchActivitiesInitialData() {
        Task {
            await fetchActivities()
        }
    }

    // MARK: - Data Loading
    func fetchActivities() async {
        guard let userId = preference.user?.id else { return }

        do {
            viewState = .loading
            let result = try await activityRepository.fetchActivitiesBy(userId: userId, limit: ACTIVITIES_LIMIT)

            activities = result.data
            lastDocument = result.lastDocument
            hasMoreActivities = !(result.data.count < self.ACTIVITIES_LIMIT)

            viewState = .initial
            activityListState = activities.isEmpty ? .noActivity : .hasActivity
        } catch {
            handleServiceError()
        }
    }

    func loadMoreActivities() {
        Task {
            await fetchMoreActivities()
        }
    }

    private func fetchMoreActivities() async {
        guard hasMoreActivities, let userId = preference.user?.id else { return }

        do {
            let result = try await activityRepository.fetchActivitiesBy(userId: userId, limit: ACTIVITIES_LIMIT, lastDocument: lastDocument)

            activities.append(contentsOf: result.data)
            lastDocument = result.lastDocument
            hasMoreActivities = !(result.data.count < self.ACTIVITIES_LIMIT)

            viewState = .initial
            activityListState = activities.isEmpty ? .noActivity : .hasActivity
        } catch {
            viewState = .initial
            showToastForError()
        }
    }

    func fetchMemberData(for userId: String) async -> AppUser? {
        if let existingUser = groupMemberData.first(where: { $0.id == userId }) {
            return existingUser // Return the available user from groupMemberData
        } else {
            do {
                let user = try await groupRepository.fetchMemberBy(userId: userId)
                if let user {
                    self.groupMemberData.append(user)
                }
                return user
            } catch {
                showToastForError()
                return nil
            }
        }
    }

    // Fetch and return user name from the cache, or fetch from API if not cached
    func getMemberName(for userId: String?) -> String {
        guard let userId else { return "Unknown" }

        if let user = groupMemberData.first(where: { $0.id == userId }) {
            return user.nameWithLastInitial
        } else {
            Task {
                let fetchedUser = await fetchMemberData(for: userId)
                return fetchedUser?.nameWithLastInitial
            }
            return "Unknown" // Return Unknown while waiting for async fetch
        }
    }

    // MARK: - User Actions
    func handleActivityItemTap(_ activity: ActivityLog) {
        switch activity.type {
        case .groupCreated, .groupNameUpdated, .groupImageUpdated, .groupMemberRemoved, .groupMemberLeft:
            router.push(.GroupHomeView(groupId: activity.activityId))
        case .groupDeleted:
            router.push(.GroupHomeView(groupId: activity.activityId))
        case .expenseAdded, .expenseUpdated, .expenseDeleted:
            router.push(.ExpenseDetailView(groupId: activity.groupId, expenseId: activity.activityId))
        case .transactionAdded, .transactionUpdated, .transactionDeleted:
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
}

// MARK: - Group States
extension ActivityLogViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }

    enum ActivityListState {
        case noActivity
        case hasActivity
    }
}
