import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
    static let pauseResumeTimer = Self("pauseResumeTimer")
}

private struct IntervalsView: View {
    @EnvironmentObject var timer: TBTimer
    private var minStr = NSLocalizedString("IntervalsView.min", comment: "min")

    var body: some View {
        VStack {
            Stepper(value: $timer.workIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalLength.label",
                                           comment: "Work interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.workIntervalLength))
                }
            }
            Stepper(value: $timer.shortRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.shortRestIntervalLength.label",
                                           comment: "Short rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.shortRestIntervalLength))
                }
            }
            Stepper(value: $timer.longRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.longRestIntervalLength.label",
                                           comment: "Long rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.longRestIntervalLength))
                }
            }
            .help(NSLocalizedString("IntervalsView.longRestIntervalLength.help",
                                    comment: "Long rest interval hint"))
            Stepper(value: $timer.workIntervalsInSet, in: 1 ... 10) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalsInSet.label",
                                           comment: "Work intervals in a set label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.workIntervalsInSet)")
                }
            }
            .help(NSLocalizedString("IntervalsView.workIntervalsInSet.help",
                                    comment: "Work intervals in set hint"))
            Stepper(value: $timer.dailyGoalMinutes, in: 15 ... 720, step: 15) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.dailyGoal.label",
                                           comment: "Daily goal label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(TBTimer.formatDuration(minutes: timer.dailyGoalMinutes))
                }
            }
            .help(NSLocalizedString("IntervalsView.dailyGoal.help",
                                    comment: "Daily goal hint"))
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
    case intervals, activity, settings, sounds
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
                                        Text(session.note)
                                            .font(.system(size: 11))
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                    }
                                    if !session.tags.isEmpty {
                                        HStack(spacing: 3) {
                                            ForEach(session.tags, id: \.self) { tag in
                                                Text("#\(tag)")
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundColor(.accentColor)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.accentColor.opacity(0.12))
                                                    .cornerRadius(3)
                                            }
                                        }
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
                                    .fill(item.isToday ? Color.accentColor : (item.minutes > 0 ? Color.secondary.opacity(0.55) : Color.secondary.opacity(0.2)))
                                    .frame(width: 14, height: barHeight)
                                Text(item.day)
                                    .font(.system(size: 9, weight: item.isToday ? .bold : .regular))
                                    .foregroundColor(item.isToday ? .accentColor : .secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)

                    let tags = sessionStore.tagBreakdown()
                    if tags.isEmpty {
                        Text(NSLocalizedString("ActivityView.noTags.title",
                                               comment: "No tags title"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    } else {
                        VStack(spacing: 3) {
                            ForEach(tags.prefix(3), id: \.tag) { item in
                                HStack {
                                    Text("#\(item.tag)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                    Text(TBTimer.formatDuration(minutes: item.minutes))
                                        .font(.system(size: 10).monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
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
                        timer.pauseResume()
                    } label: {
                        HStack(spacing: 4) {
                            if timer.state.isPaused {
                                Image(systemName: "play.fill")
                                Text("\(resumeLabel) \(timer.timeLeftString)")
                            } else {
                                Image(systemName: "pause.fill")
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

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if timer.dailyCompletedMinutes >= timer.dailyGoalMinutes {
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
                ProgressView(value: min(1.0, Double(timer.dailyCompletedMinutes) / Double(max(1, timer.dailyGoalMinutes))))
                    .progressViewStyle(.linear)
                    .accentColor(timer.dailyCompletedMinutes >= timer.dailyGoalMinutes ? .green : .red)
            }
            .padding(.vertical, 2)

            HStack(spacing: 5) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField(
                    NSLocalizedString("TBPopoverView.note.placeholder", comment: "Task note placeholder"),
                    text: $timer.sessionStore.currentTaskNote
                )
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11))
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

            Picker("", selection: $activeChildView) {
                Text(NSLocalizedString("TBPopoverView.intervals.label",
                                       comment: "Intervals label")).tag(ChildView.intervals)
                Text(NSLocalizedString("TBPopoverView.activity.label",
                                       comment: "Activity label")).tag(ChildView.activity)
                Text(NSLocalizedString("TBPopoverView.settings.label",
                                       comment: "Settings label")).tag(ChildView.settings)
                Text(NSLocalizedString("TBPopoverView.sounds.label",
                                       comment: "Sounds label")).tag(ChildView.sounds)
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
                case .settings:
                    SettingsView().environmentObject(timer)
                case .sounds:
                    SoundsView().environmentObject(timer.player)
                }
            }
            .frame(height: 180)

            Group {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                } label: {
                    Text(NSLocalizedString("TBPopoverView.about.label",
                                           comment: "About label"))
                    Spacer()
                    Text("⌘ A").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("a")
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
