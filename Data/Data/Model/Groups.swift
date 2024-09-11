//
//  Groups.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import FirebaseFirestore

public struct Groups: Codable, Identifiable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    public var name: String
    public var createdBy: String
    public var imageUrl: String?
    public var members: [String]
    public var balances: [GroupMemberBalance]
    public let createdAt: Timestamp
    public var hasExpenses: Bool
    public var isActive: Bool

    public init(name: String, createdBy: String, imageUrl: String? = nil, members: [String],
                balances: [GroupMemberBalance], createdAt: Timestamp, hasExpenses: Bool = false, isActive: Bool = true) {
        self.name = name
        self.createdBy = createdBy
        self.members = members
        self.balances = balances

        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.hasExpenses = hasExpenses
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case members
        case balances
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case hasExpenses = "has_expenses"
        case isActive = "is_active"
    }
}

public struct GroupMemberBalance: Codable {
    public let id: String /// Member Id
    public var balance: Double
    public var totalSummary: [GroupTotalSummary]

    public init(id: String, balance: Double, totalSummary: [GroupTotalSummary]) {
        self.id = id
        self.balance = balance
        self.totalSummary = totalSummary
    }

    enum CodingKeys: String, CodingKey {
        case id
        case balance
        case totalSummary = "total_summary"
    }
}

public struct GroupTotalSummary: Codable {
    public var year: Int
    public var month: Int
    public var summary: GroupMemberSummary

    public init(year: Int, month: Int, summary: GroupMemberSummary) {
        self.year = year
        self.month = month
        self.summary = summary
    }
}

public struct GroupMemberSummary: Codable {
    /// Total group's expense
    public var groupTotalSpending: Double
    /// Paid amount with expense
    public var totalPaidAmount: Double
    /// Total split amount
    public var totalShare: Double
    /// Paid amount with transaction
    public var paidAmount: Double
    /// Received amount with transaction
    public var receivedAmount: Double
    /// Final owing amount
    public var changeInBalance: Double

    public init(groupTotalSpending: Double, totalPaidAmount: Double, totalShare: Double,
                paidAmount: Double, receivedAmount: Double, changeInBalance: Double) {
        self.groupTotalSpending = groupTotalSpending
        self.totalPaidAmount = totalPaidAmount
        self.totalShare = totalShare
        self.paidAmount = paidAmount
        self.receivedAmount = receivedAmount
        self.changeInBalance = changeInBalance
    }

    enum CodingKeys: String, CodingKey {
        case groupTotalSpending = "group_total_spending"
        case totalPaidAmount = "total_paid_amount"
        case totalShare = "total_share"
        case paidAmount = "paid_amount"
        case receivedAmount = "received_amount"
        case changeInBalance = "change_in_balance"
    }
}

// MARK: - To show group and expense together
public struct GroupInformation {
    public let group: Groups
    public let userBalance: Double
    public let memberOweAmount: [String: Double]
    public let members: [AppUser]
    public let hasExpenses: Bool

    public init(group: Groups, userBalance: Double, memberOweAmount: [String: Double], members: [AppUser], hasExpenses: Bool) {
        self.group = group
        self.userBalance = userBalance
        self.memberOweAmount = memberOweAmount
        self.members = members
        self.hasExpenses = hasExpenses
    }
}
