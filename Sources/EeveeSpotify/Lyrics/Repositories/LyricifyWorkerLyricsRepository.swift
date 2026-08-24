import Foundation

private struct LyricifyWorkerResponse: Decodable {
    struct Line: Decodable {
        let content: String
        let offsetMs: Int?
    }

    struct Translation: Decodable {
        let languageCode: String
        let lines: [String]
    }

    let timeSynced: Bool
    let lines: [Line]
    let translation: Translation?
}

final class LyricifyWorkerLyricsRepository: LyricsRepository {
    static let shared = LyricifyWorkerLyricsRepository()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.httpAdditionalHeaders = [
            "User-Agent": "EeveeSpotify v\(EeveeSpotify.version) https://github.com/whoeevee/EeveeSpotify"
        ]
        session = URLSession(configuration: configuration)
    }

    private func requestURL(for query: LyricsSearchQuery) throws -> URL {
        let configuredURL = UserDefaults.lyricifyWorkerUrl
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: configuredURL),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              components.host != nil else {
            throw LyricsError.invalidLyricifyWorkerConfiguration
        }

        let basePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        if !basePath.hasSuffix("/v1/lyrics") {
            components.path = basePath + "/v1/lyrics"
        }
        components.queryItems = [
            URLQueryItem(name: "title", value: query.title),
            URLQueryItem(name: "artist", value: query.primaryArtist),
            URLQueryItem(name: "spotifyId", value: query.spotifyTrackId),
            URLQueryItem(name: "language", value: Locale.current.languageCode)
        ]

        guard let url = components.url else {
            throw LyricsError.invalidLyricifyWorkerConfiguration
        }
        return url
    }

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        var request = URLRequest(url: try requestURL(for: query))
        let token = UserDefaults.lyricifyWorkerToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var urlResponse: URLResponse?
        var requestError: Error?

        session.dataTask(with: request) { data, response, error in
            responseData = data
            urlResponse = response
            requestError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let requestError = requestError { throw requestError }
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw LyricsError.decodingError
        }
        if httpResponse.statusCode == 401 {
            throw LyricsError.invalidLyricifyWorkerToken
        }
        if httpResponse.statusCode == 404 {
            throw LyricsError.noSuchSong
        }
        guard (200..<300).contains(httpResponse.statusCode), let responseData else {
            throw LyricsError.decodingError
        }

        let response: LyricifyWorkerResponse
        do {
            response = try JSONDecoder().decode(LyricifyWorkerResponse.self, from: responseData)
        } catch {
            writeDebugLog("[Lyricify Worker] Decode error: \(error)")
            throw LyricsError.decodingError
        }

        let indexedLines = response.lines.enumerated().sorted {
            ($0.element.offsetMs ?? 0) < ($1.element.offsetMs ?? 0)
        }
        let lines = indexedLines.map {
            LyricsLineDto(content: $0.element.content.lyricsNoteIfEmpty, offsetMs: $0.element.offsetMs)
        }
        let translation = response.translation.flatMap { translation -> LyricsTranslationDto? in
            guard translation.lines.count == response.lines.count else { return nil }
            return LyricsTranslationDto(
                languageCode: translation.languageCode,
                lines: indexedLines.map { translation.lines[$0.offset] }
            )
        }
        return LyricsDto(
            lines: lines,
            timeSynced: response.timeSynced,
            romanization: lines.map(\.content).canBeRomanized ? .canBeRomanized : .original,
            translation: translation
        )
    }
}
