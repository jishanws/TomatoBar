import Foundation
import SwiftUI

struct TBSessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let note: String
    let tags: [String]

    init(id: UUID = UUID(), startTime: Date, endTime: Date, durationMinutes: Int, note: String, tags: [String]) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.note = note
        self.tags = tags
    }
}

class TBSessionStore: ObservableObject {
    @Published var sessions: [TBSessionRecord] = []
    @AppStorage("currentTaskNote") var currentTaskNote: String = ""

    private let fileManager = FileManager.default
    private let fileName = "sessions.json"

    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TomatoBar", isDirectory: true)
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        return appFolder.appendingPathComponent(fileName)
    }

    init() {
        loadSessions()
    }

    func loadSessions() {
        guard fileManager.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([TBSessionRecord].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded.sorted { $0.endTime > $1.endTime }
    }

    func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }

    static func extractTags(from text: String) -> [String] {
        let pattern = "#([a-zA-Z0-9_-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        var tags: [String] = []
        for match in matches {
            if match.numberOfRanges > 1 {
                let tag = nsString.substring(with: match.range(at: 1)).lowercased()
                if !tags.contains(tag) {
                    tags.append(tag)
                }
            }
        }
        return tags
    }

    static let maxNoteLength = 45

    func addSession(startTime: Date, endTime: Date, durationMinutes: Int, note: String) {
        let trimmed = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNoteLength))
        let tags = Self.extractTags(from: trimmed)
        let record = TBSessionRecord(
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            note: trimmed,
            tags: tags
        )
        sessions.insert(record, at: 0)
        saveSessions()
    }

    func clearAll() {
        sessions.removeAll()
        saveSessions()
        UserDefaults.standard.removeObject(forKey: "dailyHistory")
    }

    // MARK: - Analytics Helpers

    struct TBTagStat: Identifiable {
        var id: String { tag }
        let tag: String
        let minutes: Int
        let count: Int
        let isNoTag: Bool
    }

    /// Week starts on Saturday (weekday: 7).
    /// If today is Sat (7) -> 7 % 7 = 0 days back.
    /// If today is Sun (1) -> 1 % 7 = 1 day back (Sat).
    /// If today is Fri (6) -> 6 % 7 = 6 days back (Sat).
    func startOfSaturdayWeek(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday], from: date)
        let currentWeekday = components.weekday ?? 1
        let daysToSubtract = currentWeekday % 7
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay) ?? startOfDay
    }

    var thisWeekSessions: [TBSessionRecord] {
        let startOfWeek = startOfSaturdayWeek()
        return sessions.filter { $0.endTime >= startOfWeek }
    }

    var totalWeekMinutes: Int {
        thisWeekSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Returns daily minutes for Saturday through Friday of current week
    func weeklyDailyMinutes() -> [(day: String, minutes: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let startOfWeek = startOfSaturdayWeek()
        let daySymbols = ["S", "S", "M", "T", "W", "T", "F"]
        var results: [(day: String, minutes: Int, isToday: Bool)] = []

        let today = Date()
        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: startOfWeek) else { continue }
            let isToday = calendar.isDate(dayDate, inSameDayAs: today)
            let minutes = sessions.filter { calendar.isDate($0.endTime, inSameDayAs: dayDate) }
                                  .reduce(0) { $0 + $1.durationMinutes }
            results.append((day: daySymbols[i], minutes: minutes, isToday: isToday))
        }
        return results
    }

    /// Tag breakdown sorted by highest duration, including "no tag" category
    func tagBreakdown() -> [TBTagStat] {
        var map: [String: (minutes: Int, count: Int)] = [:]
        var noTagMinutes = 0
        var noTagCount = 0

        for session in sessions {
            if session.tags.isEmpty {
                noTagMinutes += session.durationMinutes
                noTagCount += 1
            } else {
                for tag in session.tags {
                    let existing = map[tag] ?? (0, 0)
                    map[tag] = (existing.minutes + session.durationMinutes, existing.count + 1)
                }
            }
        }

        var results: [TBTagStat] = map.map {
            TBTagStat(tag: $0.key, minutes: $0.value.minutes, count: $0.value.count, isNoTag: false)
        }

        if noTagCount > 0 {
            let noTagLabel = NSLocalizedString("ActivityView.noTag.label", comment: "No tag label")
            results.append(TBTagStat(tag: noTagLabel, minutes: noTagMinutes, count: noTagCount, isNoTag: true))
        }

        return results.sorted { $0.minutes > $1.minutes }
    }
}
