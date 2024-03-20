//
//  MemberRepository.swift
//  Data
//
//  Created by Amisha Italiya on 13/03/24.
//

import Combine

public class MemberRepository: ObservableObject {

    @Inject private var store: MemberStore

    @Inject var preference: SplitoPreference
    @Inject var codeRepository: ShareCodeRepository

    private var cancelables = Set<AnyCancellable>()

    public func addMemberToMembers(member: Member, completion: @escaping (String?) -> Void) {
        store.addMember(member: member, completion: completion)
    }

    public func updateMember(member: Member) -> AnyPublisher<Void, ServiceError> {
        store.updateMember(member: member)
    }

    public func fetchMemberBy(id: String) -> AnyPublisher<Member?, ServiceError> {
        store.fetchMemberBy(id: id)
    }
}
