import SwiftState

typealias TBStateMachine = StateMachine<TBStateMachineStates, TBStateMachineEvents>

enum TBStateMachineEvents: EventType {
    case startStop, timerFired, skipRest, pauseResume
}

enum TBStateMachineStates: StateType {
    case idle, work, rest, pausedWork, pausedRest

    var isPaused: Bool {
        self == .pausedWork || self == .pausedRest
    }

    var isActive: Bool {
        self != .idle
    }
}
