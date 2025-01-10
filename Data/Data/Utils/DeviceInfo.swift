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

    public static var deviceOsVersion: String {
        UIDevice.current.systemVersion
    }

    public static var appVersionName: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
