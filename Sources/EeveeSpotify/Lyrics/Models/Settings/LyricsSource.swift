import Foundation

enum LyricsSource: Int, CaseIterable, CustomStringConvertible {
    case genius = 0
    case lrclib = 1
    case musixmatch = 2
    case petit = 3
    case notReplaced = 4
    case spicylyrics = 5
    case lyricifyWorker = 6

    public static var allCases: [LyricsSource] {
        return [.spicylyrics, .musixmatch, .lyricifyWorker, .lrclib, .genius, .petit]
    }

    var description: String {
        switch self {
        case .genius:       return "Genius"
        case .lrclib:       return "LRCLIB"
        case .musixmatch:   return "Musixmatch"
        case .lyricifyWorker: return "Lyricify Worker"
        case .petit:        return "PetitLyrics"
        case .notReplaced:  return "Spotify"
        case .spicylyrics:  return "SpicyLyrics"
        }
    }

    var isReplacingLyrics: Bool { self != .notReplaced }

    static var defaultSource: LyricsSource {
        .spicylyrics
    }
}
