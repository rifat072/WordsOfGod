//
//  APIClient.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import Foundation

final class APIClient {
    static let shared = APIClient()

    enum APIError: LocalizedError {
        case missingCredentials, badURL, badResponse, http(Int), unauthorized

        var errorDescription: String? {
            switch self {
            case .missingCredentials: "API credentials are missing. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and fill it in."
            case .badURL: "Invalid request URL."
            case .badResponse: "Unexpected server response."
            case .http(let code): "Server returned HTTP \(code)."
            case .unauthorized: "Not authorized."
            }
        }
    }

    private struct Environment {
        let tokenHost: URL
        let contentHost: URL

        static let prelive = Environment(
            tokenHost: URL(string: "https://prelive-oauth2.quran.foundation")!,
            contentHost: URL(string: "https://apis-prelive.quran.foundation/content/api/v4/")!
        )
        static let production = Environment(
            tokenHost: URL(string: "https://oauth2.quran.foundation")!,
            contentHost: URL(string: "https://apis.quran.foundation/content/api/v4/")!
        )
    }

    private struct Token {
        let accessToken: String
        let expiresAt: Date
    }

    private let clientID: String
    private let clientSecret: String
    private let environment: Environment
    private let wordAudioHost = URL(string: "https://verses.quran.com")!
    private let session: URLSession

    private var cachedToken: Token?
    private var pendingToken: Task<Token, Error>?

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        clientID = info["QFClientID"] as? String ?? ""
        clientSecret = info["QFClientSecret"] as? String ?? ""
        environment = (info["QFEnvironment"] as? String) == "prelive" ? .prelive : .production

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        session = URLSession(configuration: configuration)
    }

    func wordAudioURL(for path: String) -> URL? {
        path.hasPrefix("//") ? URL(string: "https:" + path) : wordAudioHost.appending(path: path)
    }
}

//MARK: Content
extension APIClient {
    func getChapters() async throws -> [Chapter] {
        try await get("chapters", as: ChaptersResponse.self).chapters
    }

    func getVerses(chapter: Int, translationIds: [Int], wordLanguage: String) async throws -> [Verse] {
        var query = [
            "words": "true",
            "per_page": "50",
            "word_fields": "text_uthmani,text_uthmani_tajweed,text_indopak,text_imlaei,translation,transliteration,audio_url,char_type_name",
            "language": wordLanguage,
            "word_translation_language": wordLanguage
        ]
        if !translationIds.isEmpty {
            query["translations"] = translationIds.map(String.init).joined(separator: ",")
            query["translation_fields"] = "resource_name,language_name"
        }

        var verses: [Verse] = []
        var page: Int? = 1
        while let current = page {
            query["page"] = String(current)
            let response = try await get("verses/by_chapter/\(chapter)", query: query, as: VersesPage.self)
            verses += response.verses
            page = response.pagination.next_page
        }
        return verses
    }

    func getChapterAudio(reciterId: Int, chapter: Int) async throws -> ChapterAudio {
        try await get("chapter_recitations/\(reciterId)/\(chapter)",
                      query: ["segments": "true"],
                      as: ChapterAudioResponse.self).audio_file
    }
}

//MARK: Resources
extension APIClient {
    func getChapterReciters() async throws -> [ChapterReciter] {
        try await get("resources/chapter_reciters", as: ChapterRecitersResponse.self).reciters
    }

    func getTranslationList() async throws -> [Translation] {
        try await get("resources/translations", as: TranslationListResponse.self).translations
    }
}

//MARK: Token Handling
extension APIClient {
    private func validToken() async throws -> Token {
        if let cachedToken, Date.now < cachedToken.expiresAt { return cachedToken }
        if let pendingToken { return try await pendingToken.value }

        let request = try tokenRequest()
        let fetch = Task { [session] in
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.badResponse
            }
            struct Response: Decodable {
                let access_token: String
                let expires_in: Double
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return Token(accessToken: decoded.access_token,
                         expiresAt: .now.addingTimeInterval(decoded.expires_in - 30))
        }
        pendingToken = fetch
        defer { pendingToken = nil }

        let token = try await fetch.value
        cachedToken = token
        return token
    }

    private func tokenRequest() throws -> URLRequest {
        guard !clientID.isEmpty, !clientSecret.isEmpty else { throw APIError.missingCredentials }
        let credentials = Data("\(clientID):\(clientSecret)".utf8).base64EncodedString()

        var request = URLRequest(url: environment.tokenHost.appending(path: "oauth2/token"))
        request.httpMethod = "POST"
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=client_credentials&scope=content".utf8)
        return request
    }
}

//MARK: API Call Handling
extension APIClient {
    func get<T: Decodable>(_ path: String,
                           query: [String: String] = [:],
                           as type: T.Type = T.self) async throws -> T {
        let cacheKey = ResponseCache.key(path: path, query: query)
        do {
            let data = try await fetch(path, query)
            let value = try JSONDecoder().decode(T.self, from: data)
            ResponseCache.shared.store(data, for: cacheKey)
            return value
        } catch {
            guard let cached = ResponseCache.shared.data(for: cacheKey),
                  let value = try? JSONDecoder().decode(T.self, from: cached) else { throw error }
            return value
        }
    }

    private func fetch(_ path: String, _ query: [String: String]) async throws -> Data {
        do {
            return try await perform(path, query, isRetry: false)
        } catch APIError.unauthorized {
            return try await perform(path, query, isRetry: true)
        }
    }

    private func perform(_ path: String,
                         _ query: [String: String],
                         isRetry: Bool) async throws -> Data {
        var components = URLComponents(url: environment.contentHost.appending(path: path),
                                       resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.badURL }

        let token = try await validToken()
        var request = URLRequest(url: url)
        request.setValue(token.accessToken, forHTTPHeaderField: "x-auth-token")
        request.setValue(clientID, forHTTPHeaderField: "x-client-id")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }

        switch http.statusCode {
        case 200..<300:
            return data
        case let code where [401, 403].contains(code) && !isRetry:
            cachedToken = nil
            throw APIError.unauthorized
        default:
            throw APIError.http(http.statusCode)
        }
    }
}
