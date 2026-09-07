//  SessionAlarmScheduler.swift
//  ScreenTimeNext
//
//  D-047 / D-050 — the wall-clock wake-ups for one session, in a file with no `FamilyControls` in
//  it at all.
//
//  Split out of `DeviceActivityMonitoringService` so the SHIELD ACTION extension can re-arm them
//  too: when a transition screen pauses the clock (D-050), the session's end moves, and whoever
//  moved it has to move the alarms with it. Duplicating this in a second process is how the two
//  would quietly disagree about when a session ends.
//
//  A session's moments are schedules that END at them: no events, no tokens, `repeats: false`.
//  The callback is the clock reaching a time.

import DeviceActivity
import Foundation
import ScreenTimeNextCore

enum SessionAlarmScheduler {

    /// A schedule interval must be at least 15 minutes (`MonitoringError.intervalTooShort`, D-037),
    /// so the START is pushed this far back — usually into the past, which is fine: an interval
    /// already running is a normal state and only its END is what we are waiting for.
    static let minimumIntervalSeconds: TimeInterval = 16 * 60

    /// Replace every alarm for the session ending at `endsAt`.
    static func schedule(endsAt: Date, warningOffsetsSeconds: [Int], now: Date = Date()) throws {
        let center = DeviceActivityCenter()
        clear(center: center)

        var moments: [(name: String, at: Date)] = [(MonitoringName.sessionEnd, endsAt)]
        for (index, offset) in warningOffsetsSeconds.enumerated() where offset > 0 {
            moments.append((MonitoringName.sessionWarning(index: index),
                            endsAt.addingTimeInterval(-TimeInterval(offset))))
        }

        for moment in moments {
            // A moment already past has nothing to wake us for.
            guard moment.at > now else { continue }
            let schedule = DeviceActivitySchedule(
                intervalStart: components(of: moment.at.addingTimeInterval(-minimumIntervalSeconds)),
                intervalEnd: components(of: moment.at),
                repeats: false
            )
            do {
                try center.startMonitoring(DeviceActivityName(moment.name), during: schedule, events: [:])
            } catch let error as DeviceActivityCenter.MonitoringError {
                throw mapped(error)
            } catch {
                throw ScreenTimeMonitoringError.unknown(String(describing: error))
            }
        }
    }

    static func clear(center: DeviceActivityCenter = DeviceActivityCenter()) {
        center.stopMonitoring(MonitoringName.allSessionActivities.map { DeviceActivityName($0) })
    }

    /// Hour, minute AND second: a session ends at whatever second it started plus its budget, and
    /// dropping the seconds would make "time's up" arrive up to a minute late.
    private static func components(of date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }

    static func mapped(_ error: DeviceActivityCenter.MonitoringError) -> ScreenTimeMonitoringError {
        switch error {
        case .unauthorized:      return .notAuthorized
        case .excessiveActivities: return .limitExceeded
        default:                 return .unknown(String(describing: error))
        }
    }
}
