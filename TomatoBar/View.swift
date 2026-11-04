import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
    static let pauseResumeTimer = Self("pauseResumeTimer")
}

private struct IntegerField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 44

    @State private var text: String = ""

    var body: some View {
        TextField("", text: $text, onCommit: {
            commitValue()
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        })
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .multilineTextAlignment(.trailing)
        .frame(width: width)
        .onAppear {
            text = "\(value)"
        }
        .onChange(of: value) { newValue in
            let str = "\(newValue)"
            if text != str {
                text = str
            }
        }
        .onChange(of: text) { newText in
            let digits = newText.filter { $0.isNumber }
            if digits != newText {
                text = digits
            }
            if let num = Int(digits) {
                let clamped = max(range.lowerBound, min(range.upperBound, num))
                if value != clamped {
                    value = clamped
                }
            }
        }
    }

    private func commitValue() {
        if let num = Int(text) {
            value = max(range.lowerBound, min(range.upperBound, num))
        } else {
            value = range.lowerBound
        }
        text = "\(value)"
    }
}

private struct EditableIntervalRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String = ""
    var helpText: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
            IntegerField(value: $value, range: range, width: 44)
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
            }
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
        .help(helpText)
    }
}

private struct EditableDailyGoalRow: View {
    @Binding var totalMinutes: Int
    let helpText: String

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { totalMinutes / 60 },
            set: { newHours in
                let clampedHours = max(0, min(12, newHours))
                let currentMins = totalMinutes % 60
                totalMinutes = min(720, (clampedHours * 60) + currentMins)
            }
        )
    }

    private var minsBinding: Binding<Int> {
        Binding(
            get: { totalMinutes % 60 },
            set: { newMins in
                let clampedMins = max(0, min(59, newMins))
                let currentHours = totalMinutes / 60
                totalMinutes = min(720, (currentHours * 60) + clampedMins)
            }
        )
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(NSLocalizedString("IntervalsView.dailyGoal.label", comment: "Daily goal label"))
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
            IntegerField(value: hoursBinding, range: 0...12, width: 34)
            Text("h")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            IntegerField(value: minsBinding, range: 0...59, width: 34)
            Text("m")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Stepper("", value: $totalMinutes, in: 0...720, step: 15)
                .labelsHidden()
        }
        .help(helpText)
    }
}

private struct IntervalsView: View {
    @EnvironmentObject var timer: TBTimer

    var body: some View {
        VStack(spacing: 5) {
            EditableIntervalRow(
                title: NSLocalizedString("IntervalsView.workIntervalLength.label", comment: "Work interval label"),
                value: $timer.workIntervalLength,
                range: 1...120,
                suffix: "min"
            )
            EditableIntervalRow(
                title: NSLocalizedString("IntervalsView.shortRestIntervalLength.label", comment: "Short rest interval label"),
                value: $timer.shortRestIntervalLength,
                range: 1...60,
                suffix: "min"
            )
            EditableIntervalRow(
                title: NSLocalizedString("IntervalsView.longRestIntervalLength.label", comment: "Long rest interval label"),
                value: $timer.longRestIntervalLength,
                range: 1...60,
                suffix: "min",
                helpText: NSLocalizedString("IntervalsView.longRestIntervalLength.help", comment: "Long rest interval hint")
            )
            EditableIntervalRow(
                title: NSLocalizedString("IntervalsView.workIntervalsInSet.label", comment: "Work intervals in a set label"),
                value: $timer.workIntervalsInSet,
                range: 1...20,
                suffix: "",
                helpText: NSLocalizedString("IntervalsView.workIntervalsInSet.help", comment: "Work intervals in set hint")
            )
            EditableDailyGoalRow(
                totalMinutes: $timer.dailyGoalMinutes,
                helpText: NSLocalizedString("IntervalsView.dailyGoal.help", comment: "Daily goal hint")
            )
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var timer: TBTimer
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            KeyboardShortcuts.Recorder(for: .pauseResumeTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.pauseResume.label",
                                       comment: "Pause / Resume shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $timer.stopAfterBreak) {
                Text(NSLocalizedString("SettingsView.stopAfterBreak.label",
                                       comment: "Stop after break label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $timer.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: timer.showTimerInMenuBar) { _ in
                    timer.updateTimeLeft()
                }
            Toggle(isOn: $launchAtLogin.isEnabled) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                       comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct VolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        Slider(value: $volume, in: 0...2) {
            Text(String(format: "%.1f", volume))
        }.gesture(TapGesture(count: 2).onEnded({
            volume = 1.0
        }))
    }
}

private struct SoundsView: View {
    @EnvironmentObject var player: TBPlayer

    private var columns = [
        GridItem(.flexible()),
        GridItem(.fixed(110))
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("SoundsView.isWindupEnabled.label",
                                   comment: "Windup label"))
            VolumeSlider(volume: $player.windupVolume)
            Text(NSLocalizedString("SoundsView.isDingEnabled.label",
                                   comment: "Ding label"))
            VolumeSlider(volume: $player.dingVolume)
            Text(NSLocalizedString("SoundsView.isTickingEnabled.label",
                                   comment: "Ticking label"))
            VolumeSlider(volume: $player.tickingVolume)
        }.padding(4)
        Spacer().frame(minHeight: 0)
    }
}

private enum ChildView {
    case intervals, activity, sounds, settings
}

private enum ActivitySubView {
    case history, stats
}

private struct ActivityView: View {
    @EnvironmentObject var sessionStore: TBSessionStore
    @State private var subView = ActivitySubView.history
    @State private var showingClearAlert = false

    var body: some View {
        VStack(spacing: 6) {
            Picker("", selection: $subView) {
                Text(NSLocalizedString("ActivityView.history.label",
                                       comment: "History label")).tag(ActivitySubView.history)
                Text(NSLocalizedString("ActivityView.stats.label",
                                       comment: "Stats label")).tag(ActivitySubView.stats)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if subView == .history {
                if sessionStore.sessions.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("ActivityView.empty.title",
                                               comment: "No sessions title"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("ActivityView.empty.subtitle",
                                               comment: "No sessions subtitle"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(sessionStore.sessions) { session in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(formatSessionDate(session.endTime))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(session.durationMinutes)m")
                                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(3)
                                    }
                                    if !session.note.isEmpty {
                                        formattedNoteText(session.note)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                    }
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text(NSLocalizedString("ActivityView.thisWeek.title",
                                               comment: "This week title"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(TBTimer.formatDuration(minutes: sessionStore.totalWeekMinutes))
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                    }

                    let weeklyData = sessionStore.weeklyDailyMinutes()
                    let maxMins = max(60, weeklyData.map { $0.minutes }.max() ?? 60)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<weeklyData.count, id: \.self) { i in
                            let item = weeklyData[i]
                            let barHeight = max(3.0, CGFloat(item.minutes) / CGFloat(maxMins) * 36.0)
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(item.isToday ? Color.primary.opacity(0.85) : (item.minutes > 0 ? Color.primary.opacity(0.45) : Color.secondary.opacity(0.18)))
                                    .frame(width: 14, height: barHeight)
                                Text(item.day)
                                    .font(.system(size: 9, weight: item.isToday ? .bold : .regular))
                                    .foregroundColor(item.isToday ? .primary : .secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)

                    let tags = sessionStore.tagBreakdown()
                    let maxTagMins = max(1, tags.map { $0.minutes }.max() ?? 1)
                    if tags.isEmpty {
                        Text(NSLocalizedString("ActivityView.noTags.title",
                                               comment: "No tags title"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    } else {
                        ScrollView {
                            VStack(spacing: 5) {
                                ForEach(tags) { item in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            if item.isNoTag {
                                                Text(item.tag)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text("#\(item.tag)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                            Spacer()
                                            Text(TBTimer.formatDuration(minutes: item.minutes))
                                                .font(.system(size: 10).monospacedDigit())
                                                .foregroundColor(.secondary)
                                        }
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 1.5)
                                                .fill(item.isNoTag ? Color.secondary.opacity(0.25) : Color.primary.opacity(0.6))
                                                .frame(width: max(4, geo.size.width * CGFloat(item.minutes) / CGFloat(maxTagMins)), height: 3)
                                        }
                                        .frame(height: 3)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(maxHeight: 65)
                    }
                    Spacer().frame(minHeight: 0)
                }
            }

            HStack {
                Spacer()
                Button {
                    showingClearAlert = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                        Text(NSLocalizedString("ActivityView.clear.button",
                                               comment: "Clear button"))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .alert(isPresented: $showingClearAlert) {
            Alert(
                title: Text(NSLocalizedString("ActivityView.clear.alert.title", comment: "Clear title")),
                message: Text(NSLocalizedString("ActivityView.clear.alert.message", comment: "Clear message")),
                primaryButton: .destructive(Text(NSLocalizedString("ActivityView.clear.alert.confirm", comment: "Confirm"))) {
                    sessionStore.clearAll()
                },
                secondaryButton: .cancel(Text(NSLocalizedString("ActivityView.clear.alert.cancel", comment: "Cancel")))
            )
        }
    }

    private func formattedNoteText(_ note: String) -> Text {
        let pattern = "#[a-zA-Z0-9_-]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(note).foregroundColor(.primary)
        }
        let nsString = note as NSString
        let matches = regex.matches(in: note, range: NSRange(location: 0, length: nsString.length))
        if matches.isEmpty {
            return Text(note).foregroundColor(.primary)
        }

        var result = Text("")
        var currentIndex = 0
        for match in matches {
            let matchRange = match.range
            if matchRange.location > currentIndex {
                let plainRange = NSRange(location: currentIndex, length: matchRange.location - currentIndex)
                result = result + Text(nsString.substring(with: plainRange)).foregroundColor(.primary)
            }
            let tagString = nsString.substring(with: matchRange)
            result = result + Text(tagString).foregroundColor(.primary).bold()
            currentIndex = matchRange.location + matchRange.length
        }
        if currentIndex < nsString.length {
            let remainingRange = NSRange(location: currentIndex, length: nsString.length - currentIndex)
            result = result + Text(nsString.substring(with: remainingRange)).foregroundColor(.primary)
        }
        return result
    }

    private func formatSessionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }
        return formatter.string(from: date)
    }
}

private struct ResignFocusOnBackgroundClick: NSViewRepresentable {
    func makeNSView(context: Context) -> ResignView {
        ResignView()
    }

    func updateNSView(_ nsView: ResignView, context: Context) {}

    class ResignView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            let hit = super.hitTest(point)
            return hit === self ? self : nil
        }

        override func mouseDown(with event: NSEvent) {
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(nil)
            }
        }
    }
}

struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer()
    @State private var pauseButtonHovered = false
    @State private var activeChildView = ChildView.intervals

    private var startLabel = NSLocalizedString("TBPopoverView.start.label", comment: "Start label")
    private var stopLabel = NSLocalizedString("TBPopoverView.stop.label", comment: "Stop label")
    private var pauseLabel = NSLocalizedString("TBPopoverView.pause.label", comment: "Pause label")
    private var resumeLabel = NSLocalizedString("TBPopoverView.resume.label", comment: "Resume label")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !timer.state.isActive {
                Button {
                    DispatchQueue.main.async {
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
                    timer.startStop()
                    TBStatusItem.shared.closePopover(nil)
                } label: {
                    Text(startLabel)
                        .foregroundColor(Color.white)
                        .font(.system(.body).monospacedDigit())
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                HStack(spacing: 6) {
                    Button {
                        DispatchQueue.main.async {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                        timer.pauseResume()
                    } label: {
                        HStack(spacing: 4) {
                            if timer.state.isPaused {
                                Image(systemName: "play.fill")
                                Text("\(resumeLabel) \(timer.timeLeftString)")
                            } else {
                                Text(pauseButtonHovered ? pauseLabel : timer.timeLeftString)
                            }
                        }
                        .foregroundColor(Color.white)
                        .font(.system(.body).monospacedDigit())
                        .frame(maxWidth: .infinity)
                    }
                    .onHover { over in
                        pauseButtonHovered = over
                    }
                    .controlSize(.large)

                    Button {
                        DispatchQueue.main.async {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                        timer.startStop()
                        TBStatusItem.shared.closePopover(nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text(stopLabel)
                        }
                        .foregroundColor(Color.white)
                        .font(.system(.body).monospacedDigit())
                    }
                    .controlSize(.large)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField(
                    NSLocalizedString("TBPopoverView.note.placeholder", comment: "Task note placeholder"),
                    text: $timer.sessionStore.currentTaskNote,
                    onCommit: {
                        DispatchQueue.main.async {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    }
                )
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11))
                .lineLimit(1)
                if !timer.sessionStore.currentTaskNote.isEmpty {
                    Button {
                        timer.sessionStore.currentTaskNote = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(5)
            .onChange(of: timer.sessionStore.currentTaskNote) { newValue in
                if newValue.count > TBSessionStore.maxNoteLength {
                    timer.sessionStore.currentTaskNote = String(newValue.prefix(TBSessionStore.maxNoteLength))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if timer.dailyGoalMinutes > 0 && timer.dailyCompletedMinutes >= timer.dailyGoalMinutes {
                        Text(NSLocalizedString("TBPopoverView.dailyGoal.achieved", comment: "Goal Achieved"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text(NSLocalizedString("TBPopoverView.dailyGoal.title", comment: "Daily Goal"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(TBTimer.formatDuration(minutes: timer.dailyCompletedMinutes)) / \(TBTimer.formatDuration(minutes: timer.dailyGoalMinutes))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.secondary)
                }
                ProgressView(value: timer.dailyGoalMinutes == 0 ? 0 : min(1.0, Double(timer.dailyCompletedMinutes) / Double(timer.dailyGoalMinutes)))
                    .progressViewStyle(.linear)
                    .accentColor(timer.dailyGoalMinutes > 0 && timer.dailyCompletedMinutes >= timer.dailyGoalMinutes ? .green : .red)
            }
            .padding(.vertical, 2)

            Picker("", selection: $activeChildView) {
                Text(NSLocalizedString("TBPopoverView.intervals.label",
                                       comment: "Intervals label")).tag(ChildView.intervals)
                Text(NSLocalizedString("TBPopoverView.activity.label",
                                       comment: "Activity label")).tag(ChildView.activity)
                Text(NSLocalizedString("TBPopoverView.sounds.label",
                                       comment: "Sounds label")).tag(ChildView.sounds)
                Text(NSLocalizedString("TBPopoverView.settings.label",
                                       comment: "Settings label")).tag(ChildView.settings)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .pickerStyle(.segmented)

            GroupBox {
                switch activeChildView {
                case .intervals:
                    IntervalsView().environmentObject(timer)
                case .activity:
                    ActivityView().environmentObject(timer.sessionStore)
                case .sounds:
                    SoundsView().environmentObject(timer.player)
                case .settings:
                    SettingsView().environmentObject(timer)
                }
            }
            .frame(height: 190)

            Group {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                } label: {
                    Text(NSLocalizedString("TBPopoverView.about.label",
                                           comment: "About label"))
                    Spacer()
                    Text("⌘ I").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("i")
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(NSLocalizedString("TBPopoverView.quit.label",
                                           comment: "Quit label"))
                    Spacer()
                    Text("⌘ Q").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
        }
        #if DEBUG
            .overlay(
                GeometryReader { proxy in
                    debugSize(proxy: proxy)
                }
            )
        #endif
            .padding(12)
            .background(ResignFocusOnBackgroundClick())
            .onChange(of: activeChildView) { _ in
                DispatchQueue.main.async {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
            .onAppear {
                timer.checkDayRollover()
            }
    }
}

#if DEBUG
    func debugSize(proxy: GeometryProxy) -> some View {
        print("Optimal popover size:", proxy.size)
        return Color.clear
    }
#endif
