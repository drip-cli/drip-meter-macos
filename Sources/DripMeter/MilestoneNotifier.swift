import DripMeterCore
import Foundation
import UserNotifications

/// Posts a local notification when DripStore announces a newly-crossed
/// milestone (savings) or compaction threshold (cost). Authorisation is
/// requested lazily on first need; users who deny it just won't see the
/// notification — the milestone is still recorded as celebrated so we
/// don't pester them on next refresh.
@MainActor
final class MilestoneNotifier {
    static let shared = MilestoneNotifier()

    private var hasRequestedAuth = false
    private let center = UNUserNotificationCenter.current()

    func register(with store: DripStore) {
        store.onMilestoneCrossed = { [weak self] milestone in
            self?.notifyMilestone(milestone)
        }
        store.onCompactionThresholdCrossed = { [weak self] threshold in
            self?.notifyCompaction(threshold)
        }
    }

    private func notifyMilestone(_ milestone: Milestone) {
        post(
            id: "milestone-\(milestone.rawValue)",
            title: "🎉 \(milestone.displayName)",
            body: milestone.celebrationCopy
        )
    }

    private func notifyCompaction(_ threshold: CompactionWatcher.Threshold) {
        post(
            id: "compaction-\(threshold.count)",
            title: "↺ \(threshold.count) context compactions",
            body: threshold.copy
        )
    }

    private func post(id: String, title: String, body: String) {
        ensureAuthorisation { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func ensureAuthorisation(_ completion: @escaping @Sendable (Bool) -> Void) {
        if hasRequestedAuth {
            center.getNotificationSettings { settings in
                completion(settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional)
            }
            return
        }
        hasRequestedAuth = true
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion(granted)
        }
    }
}
