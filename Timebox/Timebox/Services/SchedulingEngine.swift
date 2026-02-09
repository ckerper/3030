import Foundation

/// Pure scheduling engine: given a DayPlan and cursor time, produces [TimelineSlot].
/// Recomputed whenever tasks, events, or the current time changes. Never stored.
struct SchedulingEngine {

    /// Compute the full timeline for a day plan starting from a cursor time.
    static func computeTimeline(plan: DayPlan, startTime: Date) -> [TimelineSlot] {
        var cursor = startTime
        var slots: [TimelineSlot] = []

        // Events sorted by start time, non-completed only
        var remainingEvents = plan.events
            .filter { !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }

        // Tasks in user order, non-completed only
        let taskQueue = plan.tasks.filter { !$0.isCompleted }

        let minFragmentSeconds = TimeInterval(plan.minimumFragmentMinutes * 60)

        for task in taskQueue {
            var remainingDuration = task.duration
            var fragmentIndex = 0

            while remainingDuration > 0 {
                // Check if cursor is within an ongoing event (started before cursor, hasn't ended)
                if let ongoingIdx = remainingEvents.firstIndex(where: {
                    $0.startTime <= cursor && cursor < $0.startTime.addingTimeInterval($0.plannedDuration)
                }) {
                    let event = remainingEvents[ongoingIdx]
                    let eventEnd = event.startTime.addingTimeInterval(event.plannedDuration)
                    slots.append(.event(
                        eventId: event.id,
                        startTime: event.startTime,
                        endTime: eventEnd
                    ))
                    cursor = eventEnd
                    remainingEvents.remove(at: ongoingIdx)
                    continue
                }

                // Find next event that starts after cursor
                let nextEventIndex = remainingEvents.firstIndex { $0.startTime > cursor }

                if let eventIdx = nextEventIndex {
                    let nextEvent = remainingEvents[eventIdx]
                    let gapBeforeEvent = nextEvent.startTime.timeIntervalSince(cursor)

                    if gapBeforeEvent <= 0 || remainingDuration <= gapBeforeEvent {
                        // Task fits entirely before the event (or no gap)
                        if gapBeforeEvent <= 0 {
                            // Event starts at or before cursor — insert the event first
                            let eventEnd = nextEvent.startTime.addingTimeInterval(nextEvent.plannedDuration)
                            slots.append(.event(
                                eventId: nextEvent.id,
                                startTime: nextEvent.startTime,
                                endTime: eventEnd
                            ))
                            cursor = eventEnd
                            remainingEvents.remove(at: eventIdx)
                            continue // retry this task from new cursor
                        }

                        // Task finishes before the event
                        let fragmentEnd = cursor.addingTimeInterval(remainingDuration)
                        slots.append(.taskFragment(
                            taskId: task.id,
                            startTime: cursor,
                            endTime: fragmentEnd,
                            fragmentIndex: fragmentIndex,
                            duration: remainingDuration
                        ))
                        cursor = fragmentEnd
                        remainingDuration = 0
                    } else {
                        // Task overlaps with the event — need to fragment

                        if gapBeforeEvent >= minFragmentSeconds {
                            // Create a fragment that fills the gap
                            slots.append(.taskFragment(
                                taskId: task.id,
                                startTime: cursor,
                                endTime: nextEvent.startTime,
                                fragmentIndex: fragmentIndex,
                                duration: gapBeforeEvent
                            ))
                            remainingDuration -= gapBeforeEvent
                            fragmentIndex += 1
                        } else if gapBeforeEvent > 0 {
                            // Gap too small for a fragment — show as free time
                            slots.append(.freeTime(
                                startTime: cursor,
                                endTime: nextEvent.startTime
                            ))
                        }

                        // Insert the event
                        let eventEnd = nextEvent.startTime.addingTimeInterval(nextEvent.plannedDuration)
                        slots.append(.event(
                            eventId: nextEvent.id,
                            startTime: nextEvent.startTime,
                            endTime: eventEnd
                        ))
                        cursor = eventEnd
                        remainingEvents.remove(at: eventIdx)
                    }
                } else {
                    // No more events — task fits entirely in remaining time
                    let fragmentEnd = cursor.addingTimeInterval(remainingDuration)
                    slots.append(.taskFragment(
                        taskId: task.id,
                        startTime: cursor,
                        endTime: fragmentEnd,
                        fragmentIndex: fragmentIndex,
                        duration: remainingDuration
                    ))
                    cursor = fragmentEnd
                    remainingDuration = 0
                }
            }
        }

        // Insert any remaining events (including overlapping ones at the same time)
        for event in remainingEvents {
            let eventEnd = event.startTime.addingTimeInterval(event.plannedDuration)
            if event.startTime > cursor {
                slots.append(.freeTime(
                    startTime: cursor,
                    endTime: event.startTime
                ))
            }
            slots.append(.event(
                eventId: event.id,
                startTime: event.startTime,
                endTime: eventEnd
            ))
            cursor = max(cursor, eventEnd)
        }

        return slots
    }

    /// Compute timeline including completed items (for full calendar display).
    /// Completed tasks/events show at their actual times with actual durations.
    /// When timer state is provided, the active task is positioned based on elapsed/remaining time.
    static func computeFullTimeline(
        plan: DayPlan,
        dayStart: Date,
        activeTaskId: UUID? = nil,
        remainingTime: TimeInterval = 0,
        isOvertime: Bool = false,
        overtimeElapsed: TimeInterval = 0,
        totalDuration: TimeInterval = 0
    ) -> [TimelineSlot] {
        var allSlots: [TimelineSlot] = []
        let now = Date()

        // Add completed events at their actual times
        for event in plan.events where event.isCompleted {
            let end = event.actualEndTime ?? event.plannedEndTime
            allSlots.append(.event(
                eventId: event.id,
                startTime: event.startTime,
                endTime: end
            ))
        }

        // Add completed tasks at their actual times
        for task in plan.tasks where task.isCompleted {
            if !task.completedFragments.isEmpty {
                // Show each frozen fragment at its actual position
                for (i, frag) in task.completedFragments.enumerated() {
                    allSlots.append(.taskFragment(
                        taskId: task.id,
                        startTime: frag.startTime,
                        endTime: frag.endTime,
                        fragmentIndex: i,
                        duration: frag.duration
                    ))
                }
            } else {
                // Legacy / non-fragmented: single block
                let end = task.actualEndTime ?? now
                let start = task.actualStartTime ?? end.addingTimeInterval(-task.duration)
                allSlots.append(.taskFragment(
                    taskId: task.id,
                    startTime: start,
                    endTime: end,
                    fragmentIndex: 0,
                    duration: end.timeIntervalSince(start)
                ))
            }
        }

        // Handle the active task separately if timer state is provided
        if let activeId = activeTaskId,
           let activeTask = plan.tasks.first(where: { $0.id == activeId && !$0.isCompleted }) {

            // 1. Emit frozen completed fragments at their actual positions
            let frozenFragments = activeTask.completedFragments
            let frozenElapsed = frozenFragments.reduce(0.0) { $0 + $1.duration }
            for (i, frag) in frozenFragments.enumerated() {
                allSlots.append(.taskFragment(
                    taskId: activeId,
                    startTime: frag.startTime,
                    endTime: frag.endTime,
                    fragmentIndex: i,
                    duration: frag.duration
                ))
            }

            // 2. Compute the current (live) fragment's time span
            let currentFragStart: Date
            let currentFragEnd: Date

            if isOvertime {
                let totalElapsed = totalDuration + overtimeElapsed
                let currentElapsed = totalElapsed - frozenElapsed
                currentFragStart = now.addingTimeInterval(-currentElapsed)
                currentFragEnd = now
            } else if totalDuration > 0 {
                let totalElapsed = totalDuration - remainingTime
                let currentElapsed = max(0, totalElapsed - frozenElapsed)
                currentFragStart = now.addingTimeInterval(-currentElapsed)
                currentFragEnd = now.addingTimeInterval(remainingTime)
            } else {
                currentFragStart = now
                currentFragEnd = now.addingTimeInterval(activeTask.duration)
            }

            let currentFragIndex = frozenFragments.count

            // 3. Split the current fragment around any future non-completed events
            let overlappingEvents = plan.events.filter { event in
                !event.isCompleted &&
                event.startTime > currentFragStart &&
                event.startTime < currentFragEnd
            }.sorted { $0.startTime < $1.startTime }

            var consumedEventIds: Set<UUID> = []

            if overlappingEvents.isEmpty {
                allSlots.append(.taskFragment(
                    taskId: activeId,
                    startTime: currentFragStart,
                    endTime: currentFragEnd,
                    fragmentIndex: currentFragIndex,
                    duration: currentFragEnd.timeIntervalSince(currentFragStart)
                ))
            } else {
                var cursor = currentFragStart
                var fragmentIndex = currentFragIndex

                for event in overlappingEvents {
                    let eventEnd = event.startTime.addingTimeInterval(event.plannedDuration)

                    if event.startTime > cursor {
                        allSlots.append(.taskFragment(
                            taskId: activeId,
                            startTime: cursor,
                            endTime: event.startTime,
                            fragmentIndex: fragmentIndex,
                            duration: event.startTime.timeIntervalSince(cursor)
                        ))
                        fragmentIndex += 1
                    }

                    allSlots.append(.event(
                        eventId: event.id,
                        startTime: event.startTime,
                        endTime: eventEnd
                    ))
                    consumedEventIds.insert(event.id)

                    cursor = max(cursor, eventEnd)
                }

                if cursor < currentFragEnd {
                    allSlots.append(.taskFragment(
                        taskId: activeId,
                        startTime: cursor,
                        endTime: currentFragEnd,
                        fragmentIndex: fragmentIndex,
                        duration: currentFragEnd.timeIntervalSince(cursor)
                    ))
                }
            }

            // Compute pending timeline for remaining tasks (excluding active task)
            var pendingPlan = plan
            pendingPlan.tasks = plan.tasks.filter { $0.id != activeId }
            if !consumedEventIds.isEmpty {
                pendingPlan.events = plan.events.filter { !consumedEventIds.contains($0.id) }
            }
            let pendingStartTime = isOvertime ? now : now.addingTimeInterval(remainingTime)
            let pendingSlots = computeTimeline(plan: pendingPlan, startTime: pendingStartTime)
            allSlots.append(contentsOf: pendingSlots)
        } else {
            // No active task — compute pending timeline from now
            let pendingSlots = computeTimeline(plan: plan, startTime: now)
            allSlots.append(contentsOf: pendingSlots)
        }

        // Sort all slots by start time
        allSlots.sort { $0.startTime < $1.startTime }

        return allSlots
    }
}
