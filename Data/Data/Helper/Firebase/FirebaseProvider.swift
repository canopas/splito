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

    static public let auth: Auth = .auth()

    static public func configureFirebase() {
        FirebaseApp.configure()
    }
}
