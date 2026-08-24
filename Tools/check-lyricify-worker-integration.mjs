import { readFileSync } from "node:fs";

const read = (path) => readFileSync(path, "utf8");
const checks = [
  ["Sources/EeveeSpotify/Lyrics/Models/Settings/LyricsSource.swift", /case lyricifyWorker = 6/, "stable lyrics source raw value"],
  ["Sources/EeveeSpotify/Shared/Models/Extensions/UserDefaults+Extension.swift", /static var lyricifyWorkerUrl: String/, "Worker URL persistence"],
  ["Sources/EeveeSpotify/Shared/Models/Extensions/UserDefaults+Extension.swift", /static var lyricifyWorkerToken: String/, "Worker token persistence"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /Bearer.*Authorization/, "Bearer authentication"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /URLComponents/, "safe query construction"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /normalizedBaseURL/, "scheme-less Worker URLs are normalized"],
  ["Sources/EeveeSpotify/Settings/Sections/Lyrics/ViewModels/EeveeLyricsSettingsViewModel\+setupBindings.swift", /normalizedBaseURL/, "normalized Worker URL persistence"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /scheme == "https"/, "HTTPS-only Worker URL"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /URLQueryItem\(name: "providers", value: "netease,qqmusic,lrclib"\)/, "translation-capable providers are preferred"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /URLQueryItem\(name: "translationMode", value: "prefer"\)/, "stale original-only cache is bypassed"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /let languageCode = "zh"/, "Lyricify requests Chinese translations explicitly"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /originalIndex < translation\.lines\.count/, "partial translations retain unmatched original lines"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /displayLines\[displayIndex\]\.content = translatedLine/, "translated text replaces the aligned displayed original text"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /translatedLineCount > 0 \? \.original/, "promoted Chinese lyrics are not romanized"],
  ["Sources/EeveeSpotify/Lyrics/Repositories/LyricifyWorkerLyricsRepository.swift", /provider=[\s\S]*translatedLines=/, "safe Worker result diagnostics"],
  ["Sources/EeveeSpotify/Lyrics/CustomLyrics.x.swift", /case \.lyricifyWorker:/g, "both lyrics loading paths"],
  ["Sources/EeveeSpotify/Settings/Sections/Lyrics/Views/EeveeLyricsSettingsView+lyricsSourceSection.swift", /lyricifyWorkerConfigurationFields/, "conditional settings fields"],
  ["layout/Library/Application Support/EeveeSpotify.bundle/en.lproj/Localizable.strings", /lyricify_worker_url\s*=/, "English labels"],
  ["layout/Library/Application Support/EeveeSpotify.bundle/zh-CN.lproj/Localizable.strings", /lyricify_worker_url\s*=/, "Chinese labels"]
];

let failed = false;
for (const [path, pattern, label] of checks) {
  let content = "";
  try {
    content = read(path);
  } catch {
    console.error(`FAIL ${label}: missing ${path}`);
    failed = true;
    continue;
  }

  const matches = content.match(pattern) ?? [];
  const expectedCount = pattern.global ? 2 : 1;
  if (matches.length < expectedCount) {
    console.error(`FAIL ${label}: ${path}`);
    failed = true;
  }
}

if (failed) process.exit(1);
console.log("Lyricify Worker integration contract OK");
