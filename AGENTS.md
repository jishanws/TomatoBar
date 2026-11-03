# AGENTS.md — Project Guide & Roadmap for AI Agents

## 🍅 Project Overview
**TomatoBar (Custom Edition)** is a personalized, standalone macOS menu bar Pomodoro application owned by **`jishanws`** (forked from `ivoronin/TomatoBar` and detached into an independent repository).

* **Repository:** `git@github.com:jishanws/TomatoBar.git`
* **Bundle Identifier:** `com.github.jishanws.TomatoBar`
* **Target OS:** macOS 11.0 (Big Sur) and newer (Universal Binary: Apple Silicon + Intel)
* **Tech Stack:** Swift 5, SwiftUI, AppKit (`NSStatusItem`, `NSPopover`), `SwiftState` (FSM), `KeyboardShortcuts`, `LaunchAtLogin`

---

## 🎯 Primary Goal & Design Philosophy
This repository is an **independent personal productivity tool**, NOT an upstream contribution staging ground.

1. **Personal Workflow First:** We tailor the app specifically for the user's focus needs without being constrained by upstream conservative requirements.
2. **Do Not File Upstream PRs:** All changes belong exclusively to `jishanws/TomatoBar`.
3. **Upstream Remote Policy:** `upstream` (`https://github.com/ivoronin/TomatoBar.git`) is kept strictly to fetch future macOS compatibility fixes or upstream bug fixes via `git fetch upstream`.
4. **Identity & Branding:** Functional and architectural changes take priority. Full rebranding (app name, iconset, screenshots, and public docs) will occur later once the core feature set stabilizes.

---

## 🏗 Key Architectural Principles

### 1. State Machine (`TomatoBar/State.swift` & `TomatoBar/Timer.swift`)
All timer states and transitions **must** be driven by the finite state machine (`SwiftState`):
* **States (`TBStateMachineStates`):**
  * `.idle`: No timer active.
  * `.work`: Focus session countdown running.
  * `.rest`: Short or long rest countdown running.
  * `.pausedWork`: Work session frozen at `remainingTime`.
  * `.pausedRest`: Rest session frozen at `remainingTime`.
* **Events (`TBStateMachineEvents`):**
  * `.startStop`: Starts work from idle, or cancels any active/paused session back to idle.
  * `.pauseResume`: Toggles between running and paused states.
  * `.timerFired`: Fired when `finishTime` is reached.
  * `.skipRest`: Skips rest and starts a new work interval.
* **Rule:** Always guard `stateMachine <-! event` calls to prevent invalid transitions from triggering `fatalError`.

### 2. Time & Audio Precision
* Dispatch timers are handled via `DispatchSourceTimer` on a background queue, dispatching UI updates to `DispatchQueue.main`.
* When pausing, save exact remaining seconds in `remainingTime`. When resuming, set `finishTime = Date().addingTimeInterval(remainingTime)` and restart timer.
* Ticking audio (`player.startTicking()` / `player.stopTicking()`) must pause during `.pausedWork`.
* Resuming work must **never** replay the windup sound or reset the interval length.

### 3. UI & Popover Geometry (`TomatoBar/View.swift` & `TomatoBar/App.swift`)
* Popover size is set to `CGSize(width: 250, height: 335)` in `App.swift`.
* The main content card (`GroupBox`) uses a fixed `.frame(height: 165)` across all tabs (`Intervals`, `Settings`, `Sounds`) to prevent card collapsing or jumping when switching tabs.
* Shortcut labels should use paired action names (`Start / Stop` and `Pause / Resume`) to fit horizontally without truncation.

### 4. Localization
Every user-facing string must be declared in all three localization bundles:
* `TomatoBar/en.lproj/Localizable.strings`
* `TomatoBar/ko.lproj/Localizable.strings`
* `TomatoBar/zh-Hans.lproj/Localizable.strings`

---

## 🚀 Build, CI & Deployment Strategy

Because full Xcode requires 30-40 GB of disk space, builds are automated via **GitHub Actions**:

1. **Cloud CI (`.github/workflows/main.yml`):**
   * Automatically triggers on every push to `main` (or manual `workflow_dispatch`).
   * Runs on GitHub's macOS 15 runners with Xcode pre-installed.
   * Ad-hoc signs the application (`CODE_SIGN_IDENTITY="-"`).
   * Publishes the compiled app as a direct GitHub Release:
     `https://github.com/jishanws/TomatoBar/releases/download/prerelease/TomatoBar-<sha>.zip`
2. **Local Syntax Check:**
   Before pushing, verify Swift syntax with Apple's command-line compiler:
   ```bash
   for f in TomatoBar/*.swift; do swiftc -parse "$f"; done
   ```
3. **Local Installation Workflow:**
   To update `/Applications/TomatoBar.app`:
   ```bash
   killall TomatoBar 2>/dev/null || true
   # Download latest release zip from GitHub Releases, unzip, remove quarantine, copy to /Applications
   xattr -cr /path/to/extracted/TomatoBar.app
   rm -rf /Applications/TomatoBar.app
   cp -R /path/to/extracted/TomatoBar.app /Applications/TomatoBar.app
   open -a /Applications/TomatoBar.app
   ```

---

## 🗺 Features Roadmap

### Completed Features:
- [x] **Pause & Resume:** Sub-second freeze, audio muting, dual-button popover controls, menu bar status (`⏸ MM:SS`), global shortcut, and URL scheme.
- [x] **Daily Pomodoro Goal:** Configurable target (1-30), persistent live progress bar on main popover (`🎯 Daily Goal: X / Y 🍅`), celebration notification, and automatic midnight rollover.
- [x] **UI Polish:** Resolved text clipping, balanced shortcut labels, and fixed popover collapsing across tabs.

### High-Priority Next Features:
- [ ] **Statistics & Analytics Tab:**
  * Add a dedicated **Stats** view.
  * Visualize historical Pomodoro completion using the `dailyHistory` dictionary stored in `UserDefaults` (`[DateString: Count]`) and event logs in `~/Library/Containers/com.github.jishanws.TomatoBar/Data/Library/Caches/TomatoBar.log`.
  * Show weekly/monthly heatmaps, streak counters, and total focus hours.
- [ ] **Rebranding & Identity:**
  * Customize app icon, target naming, screenshots, and repository README once core feature set is complete.
- [ ] **Enhanced Audio & Alerts:**
  * Custom sound files or audio completion alerts.
- [ ] **macOS Shortcuts & CLI Integration:**
  * Expand `tomatobar://` URL scheme or add CLI helpers for query and control.

---

## 📋 Rules for Future AI Agents
1. **Always read this file (`AGENTS.md`) and [`plan/walkthrough.md`](file:///Users/jishan/Code/TomatoBar/plan/walkthrough.md) before starting any task.**
2. **Planning Mode:** Use the `/plan` workflow for non-trivial features. Draft architecture and UI decisions in `plan/<feature>_plan.md` before writing code.
3. **Git Hygiene:** Maintain clean commit messages following Conventional Commits (`feat:`, `fix:`, `ci:`, `docs:`). Do not commit secrets, scratchpads, or personal transcripts (protected in `.gitignore`).
4. **Verification:** Always verify syntax using `swiftc -parse`, push to trigger the cloud CI, and ensure the resulting `.app` installs and runs cleanly without regressions.
