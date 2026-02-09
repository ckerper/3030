# Calendar Mode: Design Document

## Overview

Timekerper currently operates as a sequential task timer -- you create a list of tasks with durations, and the app works through them in order. **Calendar mode** extends this with a calendar-style timeline that supports **fixed-time events** (meetings, appointments) alongside **fluid tasks** that fill the gaps between them.

The core insight: tasks reflow automatically when you finish early or run late. Events stay pinned to the clock. No more manually updating 20 calendar entries when one task runs long.

## Concepts

### Tasks (fluid)

What the app already has. A task has a planned duration but no fixed start time. Its actual position in the day is computed based on what comes before it. When an earlier task finishes early, all subsequent tasks shift earlier automatically.

### Events (pinned)

New concept. An event has a specific start time and duration. It cannot be moved by the timer flow -- it's anchored to the clock. Examples: meetings, appointments, classes, lunch.

### Fragmentation

When a task's duration would overlap with an event, the app automatically splits the task into fragments that fit in the available gaps. The task remains a single object in the data model -- fragmentation is a computed view.

**Example:** A 2-hour task starting at 10:00 AM, with events at 10:30-11:00 and 11:30-12:00:

```
10:00  Task A (fragment 1, 30 min)
10:30  Event 1
11:00  Task A (fragment 2, 30 min)
11:30  Event 2
12:00  Task A (fragment 3, 60 min)
1:00   Task B...
```

**Fragment guardrail (leading edge only):** If a fragment would start less than `minimumFragmentMinutes` (default 5) before an event, don't create the fragment -- show free time instead. This avoids "you have 2 minutes, go!" situations.

**No trailing guardrail:** Tiny tails at the end of a fragmented task are fine. If there's 2 minutes of Task A left after an event, the timer runs for 2 minutes. It'll flow into overtime naturally if needed.

## Timer Behavior

### Task Timer

Works the same as list mode. Counts down the current fragment's duration. When it reaches zero, enters overtime (counts up). User decides when to mark complete.

### Event Interruption

When an event's start time arrives while a task timer is running:

1. The timer **automatically pauses** in whatever state it's in (countdown or overtime).
2. The frozen timer state (remaining time, overtime elapsed, etc.) is preserved.
3. The UI shows the active event.
4. The event does **not** auto-end. The user taps to end it (meetings run long).
5. When the user ends the event, the timer resumes exactly where it left off.

Overtime behavior during events: if the task was 3 minutes into overtime when the event started, the timer resumes at +3:00 overtime and keeps counting up.

### Completing a Task

"Complete" always means the **entire task** is done. All future fragments of that task disappear, and the next task moves up.

A task can be marked complete during an event interruption ("I forgot to check that off before my meeting, but it's done"). The next task queues up for after the event ends.

### Events Ending

Events end when the user says they end, not when the planned duration expires. The `actualEndTime` is recorded for timesheet purposes. After an event ends, the next scheduled item (task fragment or another event) begins.

**Auto-finish on next event:** If a subsequent event's start time arrives while a previous event is still active (user hasn't tapped "done"), the previous event is **automatically completed**. Its `actualEndTime` is set to the new event's start time. This handles back-to-back meetings where the user doesn't have a chance to look at their phone between them. Without this, the app would show the first event running way overtime and the second event as missed, which doesn't reflect reality. The chain works for any number of consecutive events -- each one auto-finishes the previous.

## UI Design

### App Modes

The app has two modes, toggled in settings:

- **List mode**: Current app behavior. Task list + dial timer. No events, no clock-pinning, no timeline.
- **Calendar mode**: Calendar timeline with events + tasks. Floating progress bar. All new features described here.

Both modes share the same `TaskItem` model and core timer logic.

### Calendar Timeline View

A vertically scrollable timeline where one hour has a fixed on-screen height. Both tasks and events appear as calendar blocks -- same basic layout, different visual styling to distinguish pinned (events) from fluid (tasks).

```
╔══════════════════════════════════════╗
║ ▶ Task A           ████████░░ 18:22 ║  ← floating bar (always visible)
╚══════════════════════════════════════╝

┌──────────────────────────────────────┐
│ 10:00  Task A                        │  ← fluid block
│                                      │
│ 10:30 ┃ Team standup ┃               │  ← pinned block
│       ┃              ┃               │
│ 11:00                                │
│        Task A (continued)            │  ← same task, second fragment
│                                      │
│ 11:30 ┃ 1:1 with manager ┃          │  ← pinned block
│       ┃                  ┃           │
│ 12:00                                │
│        Task A (continued)            │  ← third fragment
│                                      │
│ 12:30                                │
│        Task B                        │
│                                      │
│ 13:00                                │
│        Task C                        │
│                                      │
│ 13:30                                │
└──────────────────────────────────────┘
          ↕ scrollable
```

**Calendar zoom**: Configurable scale setting to change how much time is represented per screen-inch. Options like 30 min, 1 hour, or 2 hours per unit. Toggled on-screen or in settings.

### Floating Progress Bar

Fixed at the top of the screen. Shows:
- Current task name and play/pause control
- A horizontal progress bar
- Time remaining on the current fragment (or overtime elapsed)
- Marked pause-points on the progress bar where events will interrupt

This is the **"head down, doing work"** view. The calendar below is the **"head up, planning"** view.

### Completed Items

Completed tasks and ended events stay on the calendar, visually desaturated. They resize to reflect their **actual** duration (not planned). A task planned for 30 minutes that was completed in 18 shows as an 18-minute block.

### Free Time Gaps

When tasks don't fill the space up to an event, the gap is visible on the calendar as empty space (since it's a proportional timeline, no gap = no space, gap = visible space).

## Data Model

### TaskItem (extended from current)

```swift
struct TaskItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval          // planned duration
    var colorName: String
    var icon: String
    var isCompleted: Bool

    // New: actual time tracking
    var actualStartTime: Date?          // when the timer first started on this task
    var actualEndTime: Date?            // when marked complete
}
```

### Event (new)

```swift
struct Event: Identifiable, Codable {
    let id: UUID
    var title: String
    var startTime: Date                 // pinned clock time
    var plannedDuration: TimeInterval   // expected length
    var colorName: String
    var isCompleted: Bool
    var actualEndTime: Date?            // when user tapped "done" (may differ from planned)
}
```

### DayPlan (new)

```swift
struct DayPlan: Identifiable, Codable {
    let id: UUID
    var date: Date                      // which calendar day
    var tasks: [TaskItem]               // ordered by user priority
    var events: [Event]                 // ordered by startTime
    var minimumFragmentMinutes: Int     // guardrail threshold, default 5
}
```

At most **2 DayPlans** exist at any time: today and yesterday. Yesterday is read-only (viewable for timesheet reference). Anything older is purged. Stored as JSON in UserDefaults.

### TimelineSlot (computed, not persisted)

```swift
enum TimelineSlot {
    case taskFragment(
        taskId: UUID,
        startTime: Date,
        endTime: Date,
        fragmentIndex: Int,             // 0 = "start Task A", 1+ = "continue Task A"
        duration: TimeInterval
    )
    case event(
        eventId: UUID,
        startTime: Date,
        endTime: Date
    )
    case freeTime(
        startTime: Date,
        endTime: Date
    )
}
```

Produced by the scheduling engine. Recomputed whenever tasks, events, or the current time changes. Never stored.

### TimerState (extended)

```swift
// Additions to existing TimerViewModel
var activeEventId: UUID?                    // non-nil when an event is in progress
var interruptedTaskId: UUID?                // task paused for the event
var interruptedRemainingTime: TimeInterval? // frozen countdown value
var interruptedOvertimeElapsed: TimeInterval? // frozen overtime value
var interruptedWasOvertime: Bool            // was it in overtime when paused?
var currentFragmentIndex: Int               // which fragment of the active task
```

## Scheduling Algorithm

The scheduling engine is a pure function: given a `DayPlan` and the current time, it produces `[TimelineSlot]`.

```
function computeTimeline(plan: DayPlan, now: Date) -> [TimelineSlot]:
    cursor = now (or day start time for historical view)
    slots = []
    events = plan.events sorted by startTime, filtered to non-completed
    taskQueue = plan.tasks filtered to non-completed, in order

    for each task in taskQueue:
        remainingDuration = task.duration

        while remainingDuration > 0:
            nextEvent = first event in events where event.startTime > cursor

            if no nextEvent, or task finishes before nextEvent starts:
                # Task fits entirely in this gap
                slot = .taskFragment(task.id, cursor, cursor + remainingDuration, fragmentIndex, remainingDuration)
                slots.append(slot)
                cursor += remainingDuration
                remainingDuration = 0

            else:
                gapBeforeEvent = nextEvent.startTime - cursor

                if gapBeforeEvent >= minimumFragmentMinutes:
                    # Create a fragment that fills the gap
                    slot = .taskFragment(task.id, cursor, nextEvent.startTime, fragmentIndex, gapBeforeEvent)
                    slots.append(slot)
                    remainingDuration -= gapBeforeEvent
                    fragmentIndex += 1
                else if gapBeforeEvent > 0:
                    # Gap too small for a fragment -- show as free time
                    slots.append(.freeTime(cursor, nextEvent.startTime))

                # Insert the event
                eventEnd = nextEvent.startTime + nextEvent.plannedDuration
                slots.append(.event(nextEvent.id, nextEvent.startTime, eventEnd))
                cursor = eventEnd
                remove nextEvent from events list

    # Insert any remaining events that fall after all tasks
    for each remaining event in events:
        if event.startTime > cursor:
            slots.append(.freeTime(cursor, event.startTime))
        eventEnd = event.startTime + event.plannedDuration
        slots.append(.event(event.id, event.startTime, eventEnd))
        cursor = eventEnd

    return slots
```

## Task Management

### Reordering

Full freedom. Tasks can be reordered freely via drag-and-drop. The timeline recomputes whenever order changes. Events cannot be reordered (they're pinned by start time).

### Clearing

- **"Clear all tasks"**: Removes all tasks from the current day plan. Should be undoable.
- **"Clear all events"**: Removes all events from the day currently being viewed. Should be undoable.

### No Automatic Rollover

If a timer is left running overnight, tasks just keep pushing forward. The app doesn't do anything special at midnight. The user cleans up manually.

## Future Enhancements (Not in v1)

- **Recurring events**: Repeat rules on events (daily, specific weekdays) that auto-populate when a new DayPlan is created.
- **Calendar import**: Pull events from the iPhone Calendar app instead of manual entry.
- **Retroactive time editing**: Manually adjust start/end times of completed items for timesheet accuracy.
- **Day-clock dial**: A circular 24-hour (or waking-hours or working-hours) dial showing the full day with colored arcs for tasks and events. Planner mode equivalent of the simple mode dial.
- **Multi-day view**: See/plan more than just today.
- **Unsplittable tasks**: Tasks that cannot be split by events, so the entire task will be moved to after the would-be-interruptive event. Example: driving to work. (Sub-genre: tasks that will truncate instead of split. Example: practice piano for up to 60 minutes, or until the next event time, whichever is shorter.)
- **Time-bound list dividers**: List dividers that will defer tasks on the calendar until a certain minimum start time. Example: Sleep (and the tasks that follow it, such as getting ready for work) may start no earlier than 9pm. If preceding tasks do not reach to/past 9pm, leave a gap in the calendar and pick back up at 9. 
