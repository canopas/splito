//
//  Feedback.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import FirebaseFirestore

public struct Feedback: Codable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    var title: String
    var description: String
    var userId: String
    var attachmentUrls: [String]?
    var appVersion: String
    var deviceName: String
    var deviceOsVersion: String
    var createdAt: Timestamp

    public init(title: String, description: String, userId: String,
                attachmentUrls: [String]? = nil, appVersion: String, deviceName: String,
                deviceOsVersion: String, createdAt: Timestamp = Timestamp()) {
        self.title = title
        self.description = description
        self.userId = userId
        self.attachmentUrls = attachmentUrls
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.deviceOsVersion = deviceOsVersion
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case userId = "user_id"
        case attachmentUrls = "attachment_urls"
        case appVersion = "app_version"
        case deviceName = "device_name"
        case deviceOsVersion = "device_os_version"
        case createdAt = "created_at"
    }
}
