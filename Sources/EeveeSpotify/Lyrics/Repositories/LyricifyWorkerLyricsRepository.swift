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

    let provider: String?
    let timeSynced: Bool
    let lines: [Line]
    let translation: Translation?
}

final class LyricifyWorkerLyricsRepository: LyricsRepository {
    static let shared = LyricifyWorkerLyricsRepository()

    static func normalizedBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.contains("://") ? trimmed : "https://\(trimmed)"
    }

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

    private func requestURL(for query: LyricsSearchQuery, options: LyricsOptions) throws -> URL {
        let configuredURL = Self.normalizedBaseURL(UserDefaults.lyricifyWorkerUrl)

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
        var queryItems = [
            URLQueryItem(name: "title", value: query.title),
            URLQueryItem(name: "artist", value: query.primaryArtist),
            URLQueryItem(name: "spotifyId", value: query.spotifyTrackId),
            URLQueryItem(name: "providers", value: "qqmusic,netease,kugou,lrclib")
        ]
        if options.romanization {
            // Keep the original lyrics so LyricsDto can apply its romanization transform.
            queryItems.append(URLQueryItem(name: "romanization", value: "true"))
        } else {
            queryItems.append(URLQueryItem(name: "language", value: "zh"))
            queryItems.append(URLQueryItem(name: "translationMode", value: "prefer"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LyricsError.invalidLyricifyWorkerConfiguration
        }
        return url
    }

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        var request = URLRequest(url: try requestURL(for: query, options: options))
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
        var displayLines = indexedLines.map {
            LyricsLineDto(content: $0.element.content.lyricsNoteIfEmpty, offsetMs: $0.element.offsetMs)
        }
        var translatedLineCount = 0
        if let translation = response.translation {
            for (displayIndex, indexedLine) in indexedLines.enumerated() {
                let originalIndex = indexedLine.offset
                guard originalIndex < translation.lines.count else { continue }
                let translatedLine = translation.lines[originalIndex]
                guard !translatedLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                displayLines[displayIndex].content = translatedLine
                translatedLineCount += 1
            }
        }

        writeDebugLog(
            "[Lyricify Worker] status=\(httpResponse.statusCode) "
                + "provider=\(response.provider ?? "unknown") "
                + "lines=\(response.lines.count) translatedLines=\(translatedLineCount)"
        )

        return LyricsDto(
            lines: displayLines,
            timeSynced: response.timeSynced,
            romanization: translatedLineCount > 0 ? .original
                : (displayLines.map(\.content).canBeRomanized ? .canBeRomanized : .original),
            translation: nil
        )
    }
}
