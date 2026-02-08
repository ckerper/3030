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
- **Key Features**:
  - Task list with time estimation
  - Pie/dial timer visualization with color-coded tasks
  - Preset templates for quick task setup
  - Undo/redo functionality
  - Gesture hints system
  - Settings for color scheme and timer display options
  - Auto-loop mode for continuous task cycling

## Key File Structure
```
Timebox/
├── Views/
│   ├── ContentView.swift          # Main app UI
│   ├── TaskListView.swift         # Task list display
│   ├── TimerDialView.swift        # Timer visualization
│   ├── Components/                # Reusable UI components
│   └── (other view files)
├── ViewModels/
│   ├── TimerViewModel.swift       # Timer state & logic
│   ├── TaskListViewModel.swift    # Task management
│   └── (other view models)
├── Models/
│   ├── TaskItem.swift             # Task data structure
│   ├── TaskListModel.swift        # List container
│   ├── AppSettings.swift          # User preferences
│   └── Preset.swift               # Preset templates
├── Services/
│   ├── CloudKitService.swift      # iCloud sync
│   ├── SmartTextParser.swift      # Natural language task parsing
│   └── GestureHintManager.swift   # UI gesture hints
└── TimeboxApp.swift               # App entry point
```

## Developer Account & Constraints
- **Apple Developer Account**: Free account (not paid/team)
- **Implications**: No access to paywalled functionality like CloudKit iCloud sync or push notifications
- **Note**: The code currently includes CloudKit references, but these won't function without an upgraded account

## Recent Development
The app was recently renamed from "Timebox" to "Timekerper" and has active development on timer logic, UI polish, and persistence. Current branch structure uses `claude/*` branches for feature development.

## Claude.md Maintenance
**Claude is welcome to update this file at any time** with information that will be frequently relevant in future prompts. When making updates, explain them to the user by saying:

> I've updated CLAUDE.md to [description of changes]

For example: "I've updated CLAUDE.md to add notes about the CloudKit sync flow after discovering it's more complex than initially apparent."

This helps keep context fresh and saves time in future conversations.
