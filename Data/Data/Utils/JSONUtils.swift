//
//  JSONUtils.swift
//  Data
//
//  Created by Amisha Italiya on 23/02/24.
//

import Foundation

public struct JSONUtils {
    public static func readJSONFromFile<T: Decodable>(fileName: String, type: T.Type, bundle: Bundle? = nil) -> T? {
        if let url = (bundle ?? Bundle.main).url(forResource: fileName, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let jsonData = try decoder.decode(T.self, from: data)
                return jsonData
            } catch {
                LogE("JSONUtils: error - \(error)")
            }
        }
        return nil
    }
}
