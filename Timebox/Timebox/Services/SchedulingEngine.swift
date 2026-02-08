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

        // Insert any remaining events that fall after all tasks
        for event in remainingEvents {
            if event.startTime > cursor {
                slots.append(.freeTime(
                    startTime: cursor,
                    endTime: event.startTime
                ))
            }
            let eventEnd = event.startTime.addingTimeInterval(event.plannedDuration)
            slots.append(.event(
                eventId: event.id,
                startTime: event.startTime,
                endTime: eventEnd
            ))
            cursor = eventEnd
        }

        return slots
    }

    /// Compute timeline including completed items (for full calendar display).
    /// Completed tasks/events show at their actual times with actual durations.
    static func computeFullTimeline(plan: DayPlan, dayStart: Date) -> [TimelineSlot] {
        var allSlots: [TimelineSlot] = []

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
            if let start = task.actualStartTime {
                let end = task.actualEndTime ?? start.addingTimeInterval(task.duration)
                allSlots.append(.taskFragment(
                    taskId: task.id,
                    startTime: start,
                    endTime: end,
                    fragmentIndex: 0,
                    duration: end.timeIntervalSince(start)
                ))
            }
        }

        // Compute pending timeline from now
        let pendingSlots = computeTimeline(plan: plan, startTime: Date())
        allSlots.append(contentsOf: pendingSlots)

        // Sort all slots by start time
        allSlots.sort { $0.startTime < $1.startTime }

        return allSlots
    }
}
