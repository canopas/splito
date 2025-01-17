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
    public var type: GroupType? = .splitExpense
    public var createdBy: String
    public var updatedBy: String?
    public var imageUrl: String?
    public var members: [String]
    public var initialBalance: Double? = 0 // for fund type group only
    public var balances: [GroupMemberBalance]
    public let createdAt: Timestamp
    public var updatedAt: Timestamp
    public var hasExpenses: Bool
    private var defaultCurrency: String? = Currency.defaultCurrency.code
    public var isActive: Bool

    public var defaultCurrencyCode: String {
        defaultCurrency ?? Currency.defaultCurrency.code
    }

    public init(name: String, type: GroupType = .splitExpense, createdBy: String, updatedBy: String? = nil,
                imageUrl: String? = nil, members: [String], initialBalance: Double = 0.0, balances: [GroupMemberBalance],
                createdAt: Timestamp = Timestamp(), updatedAt: Timestamp = Timestamp(), hasExpenses: Bool = false,
                currencyCode: String = Currency.defaultCurrency.code, isActive: Bool = true) {
        self.name = name
        self.type = type
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.imageUrl = imageUrl
        self.members = members
        self.initialBalance = initialBalance
        self.balances = balances
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hasExpenses = hasExpenses
        self.defaultCurrency = currencyCode
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case members
        case balances
        case initialBalance = "initial_balance"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hasExpenses = "has_expenses"
        case defaultCurrency = "default_currency"
        case isActive = "is_active"
    }
}

public enum GroupType: String, Codable {
    case splitExpense = "split_expense"
    case fund = "fund"
}

public struct GroupMemberBalance: Codable {
    public let id: String /// Member Id
    public var balanceByCurrency: [String: GroupCurrencyBalance] /// Currency wise member balance

    public init(id: String, balanceByCurrency: [String: GroupCurrencyBalance]) {
        self.id = id
        self.balanceByCurrency = balanceByCurrency
    }

    enum CodingKeys: String, CodingKey {
        case id
        case balanceByCurrency = "balance_by_currency"
    }
}

public struct GroupCurrencyBalance: Codable {
    public var balance: Double
    public var totalSummary: [GroupTotalSummary]

    public init(balance: Double, totalSummary: [GroupTotalSummary]) {
        self.balance = balance
        self.totalSummary = totalSummary
    }

    enum CodingKeys: String, CodingKey {
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

    enum CodingKeys: String, CodingKey {
        case year
        case month
        case summary
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
    public let userBalance: [String: Double]
    public let memberOweAmount: [String: [String: Double]]
    public let members: [AppUser]
    public let hasExpenses: Bool

    public init(group: Groups, userBalance: [String: Double], memberOweAmount: [String: [String: Double]],
                members: [AppUser], hasExpenses: Bool) {
        self.group = group
        self.userBalance = userBalance
        self.memberOweAmount = memberOweAmount
        self.members = members
        self.hasExpenses = hasExpenses
    }
}
