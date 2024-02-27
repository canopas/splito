//
//  FirebaseProvider.swift
//  Data
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import FirebaseCore
import FirebaseAuth

public class FirebaseProvider {

    public static var auth: Auth = .auth()
    public static var phoneAuthProvider: PhoneAuthProvider = .provider()

    static public func configureFirebase() {
        FirebaseApp.configure()
    }
}
