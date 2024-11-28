//
//  SelectGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Foundation

class SelectGroupViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository

    @Published var selectedGroup: Groups?
    @Published private(set) var currentViewState: ViewState = .loading

    var onGroupSelection: ((Groups) -> Void)

    init(selectedGroup: Groups?, onGroupSelection: @escaping ((Groups) -> Void)) {
        self.selectedGroup = selectedGroup
        self.onGroupSelection = onGroupSelection
        super.init()

        fetchInitialGroupsData()
    }

    func fetchInitialGroupsData() {
        Task {
            await self.fetchGroups()
        }
    }

    // MARK: - Data Loading
    private func fetchGroups() async {
        do {
            let (groups, _) = try await groupRepository.fetchGroupsBy(userId: preference.user?.id ?? "")
            currentViewState = groups.isEmpty ? .noGroups : .hasGroups(groups: groups)
            LogD("SelectGroupViewModel: \(#function) Groups fetched successfully.")
        } catch {
            LogE("SelectGroupViewModel: \(#function) Failed to fetch groups: \(error).")
            handleServiceError()
        }
    }

    // MARK: - User Actions
    func handleGroupSelection(group: Groups) {
        selectedGroup = group
    }

    func handleDoneAction() {
        if let selectedGroup {
            onGroupSelection(selectedGroup)
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
        }
    }
}

// MARK: - View States
extension SelectGroupViewModel {
    enum ViewState: Equatable {
        public static func == (lhs: SelectGroupViewModel.ViewState, rhs: SelectGroupViewModel.ViewState) -> Bool {
            return lhs.key == rhs.key
        }

        case loading
        case hasGroups(groups: [Groups])
        case noGroups
        case noInternet
        case somethingWentWrong

        public var key: String {
            switch self {
            case .loading:
                return "loading"
            case .hasGroups:
                return "hasGroups"
            case .noGroups:
                return "noGroups"
            case .noInternet:
                return "noInternet"
            case .somethingWentWrong:
                return "somethingWentWrong"
            }
        }
    }
}
