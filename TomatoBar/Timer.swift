import KeyboardShortcuts
import SwiftState
import SwiftUI

class TBTimer: ObservableObject {
    @AppStorage("stopAfterBreak") var stopAfterBreak = false
    @AppStorage("showTimerInMenuBar") var showTimerInMenuBar = true
    @AppStorage("workIntervalLength") var workIntervalLength = 25
    @AppStorage("shortRestIntervalLength") var shortRestIntervalLength = 5
    @AppStorage("longRestIntervalLength") var longRestIntervalLength = 15
    @AppStorage("workIntervalsInSet") var workIntervalsInSet = 4
    @AppStorage("dailyGoalMinutes") var dailyGoalMinutes: Int = 240
    @AppStorage("dailyCompletedMinutes") var dailyCompletedMinutes: Int = 0
    @AppStorage("dailyCompletedDate") private var dailyCompletedDate: String = ""
    // This preference is "hidden"
    @AppStorage("overrunTimeLimit") var overrunTimeLimit = -60.0

    private var stateMachine = TBStateMachine(state: .idle)
    public let player = TBPlayer()
    private var consecutiveWorkIntervals: Int = 0
    private var notificationCenter = TBNotificationCenter()
    private var finishTime: Date?
    private var remainingTime: TimeInterval = 0
    private var timerFormatter = DateComponentsFormatter()
    @Published var timeLeftString: String = ""
    @Published var timer: DispatchSourceTimer?
    @Published var state: TBStateMachineStates = .idle
    @Published var sessionStore = TBSessionStore()
    private var sessionStartTime: Date?

    init() {
        /*
         * State diagram
         *
         *                      start/stop
         *       +------------------+------------------+
         *       |                  |                  |
         *       |  start/stop      |     timerFired   |
         *       V    |             |       |          |
         * +--------+ |  +--------+ |       | +--------+
         * | idle   |--->| work   |-+       | | rest   |
         * +--------+    +--------+         | +--------+
         *   A            A   |             |   A   |
         *   |            |   |             |   |   |
         *   |  pauseResume   pauseResume   |   pauseResume
         *   |            |   |             |   |   |
         *   |            |   V             |   |   V
         *   |       +------------+         | +------------+
         *   |       | pausedWork |         | | pausedRest |
         *   |       +------------+         | +------------+
         *   |         |                    |   |
         *   |         | startStop          |   | startStop / skipRest
         *   +---------+                    |   |
         *   |                              |   |
         *   +------------------------------+---+
         */
        stateMachine.addRoutes(event: .startStop, transitions: [
            .idle => .work,
            .work => .idle,
            .rest => .idle,
            .pausedWork => .idle,
            .pausedRest => .idle,
        ])
        stateMachine.addRoutes(event: .pauseResume, transitions: [
            .work => .pausedWork,
            .pausedWork => .work,
            .rest => .pausedRest,
            .pausedRest => .rest,
        ])
        stateMachine.addRoutes(event: .timerFired, transitions: [.work => .rest])
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .idle]) { _ in
            self.stopAfterBreak
        }
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .work]) { _ in
            !self.stopAfterBreak
        }
        stateMachine.addRoutes(event: .skipRest, transitions: [
            .rest => .work,
            .pausedRest => .work,
        ])

        /*
         * "Finish" handlers are called when time interval ended
         * "End"    handlers are called when time interval ended or was cancelled
         */
        stateMachine.addAnyHandler(.any => .work, handler: onWorkStart)
        stateMachine.addAnyHandler(.work => .rest, order: 0, handler: onWorkFinish)
        stateMachine.addAnyHandler(.work => .any, order: 1, handler: onWorkEnd)
        stateMachine.addAnyHandler(.work => .pausedWork, handler: onPauseWork)
        stateMachine.addAnyHandler(.rest => .pausedRest, handler: onPauseRest)
        stateMachine.addAnyHandler(.any => .rest, handler: onRestStart)
        stateMachine.addAnyHandler(.rest => .work, handler: onRestFinish)
        stateMachine.addAnyHandler(.any => .idle, handler: onIdleStart)
        stateMachine.addAnyHandler(.any => .any, handler: { [weak self] ctx in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.state = ctx.toState
                self.updateTimeLeft()
            }
            logger.append(event: TBLogEventTransition(fromContext: ctx))
        })

        stateMachine.addErrorHandler { ctx in fatalError("state machine context: <\(ctx)>") }

        timerFormatter.unitsStyle = .positional
        timerFormatter.allowedUnits = [.minute, .second]
        timerFormatter.zeroFormattingBehavior = .pad

        KeyboardShortcuts.onKeyUp(for: .startStopTimer, action: startStop)
        KeyboardShortcuts.onKeyUp(for: .pauseResumeTimer, action: pauseResume)
        notificationCenter.setActionHandler(handler: onNotificationAction)
        checkDayRollover()

        let aem: NSAppleEventManager = NSAppleEventManager.shared()
        aem.setEventHandler(self,
                            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
                            forEventClass: AEEventClass(kInternetEventClass),
                            andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                 withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.forKeyword(AEKeyword(keyDirectObject))?.stringValue else {
            print("url handling error: cannot get url")
            return
        }
        let url = URL(string: urlString)
        guard url != nil,
              let scheme = url!.scheme,
              let host = url!.host else {
            print("url handling error: cannot parse url")
            return
        }
        guard scheme.caseInsensitiveCompare("tomatobar") == .orderedSame else {
            print("url handling error: unknown scheme \(scheme)")
            return
        }
        switch host.lowercased() {
        case "startstop":
            startStop()
        case "pauseresume":
            pauseResume()
        case "pause":
            if !stateMachine.state.isPaused {
                pauseResume()
            }
        case "resume":
            if stateMachine.state.isPaused {
                pauseResume()
            }
        default:
            print("url handling error: unknown command \(host)")
            return
        }
    }

    func startStop() {
        stateMachine <-! .startStop
    }

    func pauseResume() {
        guard stateMachine.state != .idle else { return }
        stateMachine <-! .pauseResume
    }

    func skipRest() {
        guard stateMachine.state == .rest || stateMachine.state == .pausedRest else { return }
        stateMachine <-! .skipRest
    }

    func updateTimeLeft() {
        if stateMachine.state.isPaused {
            timeLeftString = timerFormatter.string(from: max(0, remainingTime)) ?? "00:00"
            if showTimerInMenuBar {
                TBStatusItem.shared.setTitle(title: timeLeftString, color: .systemYellow)
            } else {
                TBStatusItem.shared.setTitle(title: nil)
            }
            return
        }

        if let finishTime = finishTime {
            timeLeftString = timerFormatter.string(from: Date(), to: finishTime) ?? ""
        }
        if timer != nil, showTimerInMenuBar {
            TBStatusItem.shared.setTitle(title: timeLeftString, color: nil)
        } else {
            TBStatusItem.shared.setTitle(title: nil)
        }
    }

    private func startTimer(timeInterval: TimeInterval) {
        finishTime = Date().addingTimeInterval(timeInterval)

        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer!.setEventHandler(handler: onTimerTick)
        timer!.setCancelHandler(handler: onTimerCancel)
        timer!.resume()
    }

    private func startTimer(seconds: Int) {
        startTimer(timeInterval: TimeInterval(seconds))
    }

    private func stopTimer() {
        if let activeTimer = timer {
            activeTimer.cancel()
            timer = nil
        }
    }

    private func onTimerTick() {
        /* Cannot publish updates from background thread */
        DispatchQueue.main.async { [self] in
            updateTimeLeft()
            guard let finishTime = finishTime else { return }
            let timeLeft = finishTime.timeIntervalSince(Date())
            if timeLeft <= 0 {
                /*
                 Ticks can be missed during the machine sleep.
                 Stop the timer if it goes beyond an overrun time limit.
                 */
                if timeLeft < overrunTimeLimit {
                    stateMachine <-! .startStop
                } else {
                    stateMachine <-! .timerFired
                }
            }
        }
    }

    private func onTimerCancel() {
        DispatchQueue.main.async { [self] in
            updateTimeLeft()
        }
    }

    private func onNotificationAction(action: TBNotification.Action) {
        if action == .skipRest, (stateMachine.state == .rest || stateMachine.state == .pausedRest) {
            skipRest()
        }
    }

    private func onWorkStart(context ctx: TBStateMachine.Context) {
        if ctx.fromState == .pausedWork {
            onResumeWork(context: ctx)
            return
        }
        remainingTime = 0
        sessionStartTime = Date()
        TBStatusItem.shared.setIcon(name: .work)
        player.playWindup()
        player.startTicking()
        startTimer(seconds: workIntervalLength * 60)
    }

    private func onResumeWork(context _: TBStateMachine.Context) {
        TBStatusItem.shared.setIcon(name: .work)
        player.startTicking()
        startTimer(timeInterval: remainingTime)
    }

    private func onPauseWork(context _: TBStateMachine.Context) {
        if let finishTime = finishTime {
            remainingTime = max(0, finishTime.timeIntervalSince(Date()))
        }
        stopTimer()
        player.stopTicking()
    }

    private func onWorkFinish(context _: TBStateMachine.Context) {
        consecutiveWorkIntervals += 1
        player.playDing()

        let start = sessionStartTime ?? Date().addingTimeInterval(-Double(workIntervalLength * 60))
        sessionStore.addSession(
            startTime: start,
            endTime: Date(),
            durationMinutes: workIntervalLength,
            note: sessionStore.currentTaskNote
        )
        sessionStartTime = nil

        checkDayRollover()
        let previousMinutes = dailyCompletedMinutes
        dailyCompletedMinutes += workIntervalLength
        recordDailyHistory(date: todayDateString(), minutes: dailyCompletedMinutes)

        if dailyGoalMinutes > 0 && dailyCompletedMinutes >= dailyGoalMinutes && previousMinutes < dailyGoalMinutes {
            let formattedGoal = TBTimer.formatDuration(minutes: dailyGoalMinutes)
            notificationCenter.send(
                title: NSLocalizedString("TBTimer.goalReached.title", comment: "Daily goal achieved"),
                body: String(format: NSLocalizedString("TBTimer.goalReached.body", comment: "Goal body"), formattedGoal),
                category: .restStarted
            )
        }
    }

    static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%dh %02dm", hours, mins)
    }

    func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func checkDayRollover() {
        let today = todayDateString()
        if dailyCompletedDate.isEmpty {
            dailyCompletedDate = today
        } else if dailyCompletedDate != today {
            dailyCompletedDate = today
            dailyCompletedMinutes = 0
        }
    }

    private func recordDailyHistory(date: String, minutes: Int) {
        var history = UserDefaults.standard.dictionary(forKey: "dailyHistory") as? [String: Int] ?? [:]
        history[date] = minutes
        UserDefaults.standard.set(history, forKey: "dailyHistory")
    }

    private func onWorkEnd(context _: TBStateMachine.Context) {
        player.stopTicking()
    }

    private func onRestStart(context ctx: TBStateMachine.Context) {
        if ctx.fromState == .pausedRest {
            onResumeRest(context: ctx)
            return
        }
        remainingTime = 0
        var body = NSLocalizedString("TBTimer.onRestStart.short.body", comment: "Short break body")
        var length = shortRestIntervalLength
        var imgName = NSImage.Name.shortRest
        if consecutiveWorkIntervals >= workIntervalsInSet {
            body = NSLocalizedString("TBTimer.onRestStart.long.body", comment: "Long break body")
            length = longRestIntervalLength
            imgName = .longRest
            consecutiveWorkIntervals = 0
        }
        notificationCenter.send(
            title: NSLocalizedString("TBTimer.onRestStart.title", comment: "Time's up title"),
            body: body,
            category: .restStarted
        )
        TBStatusItem.shared.setIcon(name: imgName)
        startTimer(seconds: length * 60)
    }

    private func onResumeRest(context _: TBStateMachine.Context) {
        let imgName: NSImage.Name = consecutiveWorkIntervals >= workIntervalsInSet ? .longRest : .shortRest
        TBStatusItem.shared.setIcon(name: imgName)
        startTimer(timeInterval: remainingTime)
    }

    private func onPauseRest(context _: TBStateMachine.Context) {
        if let finishTime = finishTime {
            remainingTime = max(0, finishTime.timeIntervalSince(Date()))
        }
        stopTimer()
    }

    private func onRestFinish(context ctx: TBStateMachine.Context) {
        if ctx.event == .skipRest {
            return
        }
        notificationCenter.send(
            title: NSLocalizedString("TBTimer.onRestFinish.title", comment: "Break is over title"),
            body: NSLocalizedString("TBTimer.onRestFinish.body", comment: "Break is over body"),
            category: .restFinished
        )
    }

    private func onIdleStart(context _: TBStateMachine.Context) {
        stopTimer()
        remainingTime = 0
        sessionStartTime = nil
        player.stopTicking()
        TBStatusItem.shared.setIcon(name: .idle)
        TBStatusItem.shared.setTitle(title: nil)
        consecutiveWorkIntervals = 0
    }
}
