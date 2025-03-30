//
//  Encodable+Dictionary.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//
import Foundation

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        guard let dictionary = jsonObject as? [String: Any] else {
            throw NSError(domain: "Invalid JSON", code: 0, userInfo: nil)
        }
        return dictionary
    }
}
