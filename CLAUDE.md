# Claude Development Guidelines

## User Profile
**Important:** The developer is new to iPhone app coding. Please provide explicit, step-by-step instructions for:
- **Terminal commands**: Only assume the user is comfortable with `git pull`. For any other terminal operation, provide complete, explicit instructions.
- **Xcode**: Only assume the user can connect a device and hit `cmd+R`. For anything beyond that, provide detailed guidance.

## Project Scope
- **App Name**: Timekerper (formerly Timebox)
- **Purpose**: Personal task timer/timeboxing app for the developer's single device
- **Distribution**: NOT intended for App Store distribution or monetization — this is a personal tool only
- **Target Device**: iOS (iPhone)

## Project Architecture
- **Framework**: SwiftUI (modern Apple UI framework)
- **Data Sync**: CloudKit (iCloud integration via `NSUbiquitousKeyValueStore`)
- **App Modes**: Two modes toggled in Settings:
  - **List mode**: Original sequential task list + dial/pie timer
  - **Calendar mode**: Calendar-style vertical timeline with fixed events + fluid tasks
- **Key Features**:
  - Task list with time estimation
  - Pie/dial timer visualization with color-coded tasks
  - Calendar timeline with events (pinned) and tasks (fluid)
  - Scheduling engine that auto-fragments tasks around events
  - Event interruption (auto-pauses task timer when events start)
  - Preset templates for quick task setup
  - Undo/redo functionality
  - Gesture hints system
  - Settings for color scheme, timer display, and calendar zoom
  - Auto-loop mode for continuous task cycling (list mode only)

## Key File Structure
```
Timebox/
├── Views/
│   ├── ContentView.swift          # Main app UI (mode switching)
│   ├── TaskListView.swift         # Task list display (list mode)
│   ├── TimerDialView.swift        # Timer visualization (list mode)
│   ├── CalendarModeView.swift     # Calendar mode container
│   ├── CalendarTimelineView.swift # Scrollable calendar timeline
│   ├── AddEventView.swift         # Event creation sheet
│   ├── EventEditView.swift        # Event editing sheet
│   ├── Components/
│   │   ├── FloatingProgressBar.swift  # Calendar mode progress bar
│   │   ├── PieTimerView.swift
│   │   ├── ColorPalette.swift
│   │   ├── IconPicker.swift
│   │   └── TimeDividerView.swift
│   └── (other view files)
├── ViewModels/
│   ├── TimerViewModel.swift       # Timer state & logic (both modes)
│   ├── TaskListViewModel.swift    # Task management (list mode)
│   ├── DayPlanViewModel.swift     # Day plan management (calendar mode)
│   └── (other view models)
├── Models/
│   ├── TaskItem.swift             # Task data structure
│   ├── Event.swift                # Calendar event (pinned time)
│   ├── DayPlan.swift              # Day container (tasks + events)
│   ├── TimelineSlot.swift         # Computed timeline entries
│   ├── TaskListModel.swift        # List container (list mode)
│   ├── AppSettings.swift          # User preferences (incl. appMode)
│   └── Preset.swift               # Preset templates
├── Services/
│   ├── SchedulingEngine.swift     # Pure function: DayPlan → [TimelineSlot]
│   ├── CloudKitService.swift      # iCloud sync
│   ├── SmartTextParser.swift      # Natural language task parsing
│   └── GestureHintManager.swift   # UI gesture hints
└── TimeboxApp.swift               # App entry point
```

## Calendar Mode Architecture
- **SchedulingEngine**: Pure function `computeTimeline(plan:startTime:)` that fragments tasks around events
- **DayPlanViewModel**: Manages DayPlan (tasks + events), persistence, undo/redo, timeline recomputation
- **TimerViewModel**: Extended with `activeEventId`, `isTimingEvent`, event interruption/completion logic
- **Design doc**: See `PLANNER_DESIGN.md` for full specification

## Build Environment
- **No Xcode or Swift compiler** is available in the Claude Code remote environment — do not attempt `xcodebuild` or `swift build` to verify compilation. The user builds locally on their Mac.

## Developer Account & Constraints
- **Apple Developer Account**: Free account (not paid/team)
- **Implications**: No access to paywalled functionality like CloudKit iCloud sync or push notifications
- **Note**: The code currently includes CloudKit references, but these won't function without an upgraded account

## Recent Development
The app was recently renamed from "Timebox" to "Timekerper" and has active development on timer logic, UI polish, and persistence. Current branch structure uses `claude/*` branches for feature development.

Calendar mode was added as a major feature alongside the existing list mode. The two modes share TaskItem model and core timer logic but have separate view hierarchies and view models.

## Claude.md Maintenance
**Claude is welcome to update this file at any time** with information that will be frequently relevant in future prompts. When making updates, explain them to the user by saying:

> I've updated CLAUDE.md to [description of changes]

For example: "I've updated CLAUDE.md to add notes about the CloudKit sync flow after discovering it's more complex than initially apparent."

This helps keep context fresh and saves time in future conversations.
