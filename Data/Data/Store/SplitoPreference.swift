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
        case isLoggedIn = "is_logged_in"
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
    
    public var isLoggedIn: Bool {
        get {
            return userDefaults.bool(forKey: Key.isLoggedIn.rawValue)
        } set {
            userDefaults.set(newValue, forKey: Key.isLoggedIn.rawValue)
            userDefaults.synchronize()
        }
    }
}
