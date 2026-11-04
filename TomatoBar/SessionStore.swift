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

    func addSession(startTime: Date, endTime: Date, durationMinutes: Int, note: String) {
        let tags = Self.extractTags(from: note)
        let record = TBSessionRecord(
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
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

    var thisWeekSessions: [TBSessionRecord] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return []
        }
        return sessions.filter { $0.endTime >= startOfWeek }
    }

    var totalWeekMinutes: Int {
        thisWeekSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Returns daily minutes for Monday through Sunday of current week
    func weeklyDailyMinutes() -> [(day: String, minutes: Int, isToday: Bool)] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return []
        }

        let daySymbols = ["M", "T", "W", "T", "F", "S", "S"]
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

    /// Tag breakdown with total minutes and percentage of total tagged time
    func tagBreakdown() -> [(tag: String, minutes: Int, count: Int)] {
        var map: [String: (minutes: Int, count: Int)] = [:]
        for session in sessions {
            for tag in session.tags {
                let existing = map[tag] ?? (0, 0)
                map[tag] = (existing.minutes + session.durationMinutes, existing.count + 1)
            }
        }
        return map.map { (tag: $0.key, minutes: $0.value.minutes, count: $0.value.count) }
                  .sorted { $0.minutes > $1.minutes }
    }
}
