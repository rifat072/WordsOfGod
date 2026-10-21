//
//  ResponseCache.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import Foundation

final class ResponseCache {
    static let shared = ResponseCache()

    private let directory = OfflineStorage.directory("Responses")

    static func key(path: String, query: [String: String]) -> String {
        let sortedQuery = query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(path)?\(sortedQuery)"
    }

    func data(for key: String) -> Data? {
        try? Data(contentsOf: fileURL(for: key))
    }

    func store(_ data: Data, for key: String) {
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    var size: Int64 { OfflineStorage.size(of: directory) }

    func clear() { OfflineStorage.removeContents(of: directory) }

    private func fileURL(for key: String) -> URL {
        directory.appending(path: OfflineStorage.fileName(for: key, extension: "json"))
    }
}
