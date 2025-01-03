//
//  DeviceInfo.swift
//  Data
//
//  Created by Nirali Sonani on 02/01/25.
//

import UIKit

public class DeviceInfo {

    public static var deviceName: String {
        UIDevice.current.name
    }

    public static var currentOsVersion: String {
        UIDevice.current.systemVersion
    }

    public static var buildVersion: Int {
        if let result = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return Int(result) ?? 0
        } else {
            return 0
        }
    }

    public static var appVersionName: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
