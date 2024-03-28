//
//  ChoosePayerViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Combine

class ChoosePayerViewModel: BaseViewModel, ObservableObject {

    @Inject var memberRepository: MemberRepository

    @Published var groupId: String
    @Published var currentViewState: ViewState = .initial

    @Published var members: [Member] = []
    @Published var selectedMember: Member?

    init(groupId: String) {
        self.groupId = groupId
        super.init()

        self.fetchMembers()
    }

    func fetchMembers() {
        currentViewState = .loading
        memberRepository.fetchMembersByGroup(id: groupId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { members in
                print("XXX --- Member: \(members.count)")
                self.currentViewState = .success(member: members)
            }
            .store(in: &cancelables)
    }
}

extension ChoosePayerViewModel {
    enum ViewState {
        case initial
        case loading
        case success(member: [Member])
    }
}
