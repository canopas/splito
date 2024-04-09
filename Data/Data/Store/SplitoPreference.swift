//
//  SplitoPreference.swift
//  Data
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation

public class SplitoPreference {

    enum Key: String {
        case isOnboardShown = "is_onboard_shown"
        case isVerifiedUser = "is_verified_user"
        case user           = "user"
    }

    private let userDefaults: UserDefaults

    init() {
        self.userDefaults = UserDefaults.standard
    }

    public var isOnboardShown: Bool {
        get {
            return userDefaults.bool(forKey: Key.isOnboardShown.rawValue)
        } set {
            userDefaults.set(newValue, forKey: Key.isOnboardShown.rawValue)
            userDefaults.synchronize()
        }
    }

    public var isVerifiedUser: Bool {
        get {
            return userDefaults.bool(forKey: Key.isVerifiedUser.rawValue)
        } set {
            userDefaults.set(newValue, forKey: Key.isVerifiedUser.rawValue)
            userDefaults.synchronize()
        }
    }

    public var user: AppUser? {
        get {
            do {
                let data = userDefaults.data(forKey: Key.user.rawValue)
                if let data {
                    let user = try JSONDecoder().decode(AppUser.self, from: data)
                    return user
                }
            } catch let error {
                LogE("AppPreferences \(#function) json decode error: \(error.localizedDescription)")
            }
            return nil
        } set {
            do {
                let data = try JSONEncoder().encode(newValue)
                userDefaults.set(data, forKey: Key.user.rawValue)
            } catch let error {
                LogE("AppPreferences \(#function) json encode error: \(error.localizedDescription)")
            }
        }
    }

    public func clearPreference() {
        user = nil
        isVerifiedUser = false
    }
}
