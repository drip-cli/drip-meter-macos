import Foundation

/// Generates a portable Markdown report of the user's DRIP usage. Designed
/// to be saveable to disk or pasted into a note — no images, no fancy
/// tables that GitHub-style renderers might butcher.
///
/// Sections:
///   1. Header (generated date, scope, DRIP install summary)
///   2. Lifetime totals (tokens / dollars / CO₂ / reduction)
///   3. Streak summary (current + best + active days this week)
///   4. Last 7 days table
///   5. Last 30 days table + daily average
///   6. Per-agent breakdown
///   7. Top files (up to 10)
public enum UsageReport {
    public struct Input: Sendable {
        public let report: MeterReport
        public let agents: [AgentBreakdown]
        public let topFiles: [MeterReport.PerFile]
        public let currentStreak: Int
        public let bestStreak: Int
        public let activeDaysThisWeek: Int
        public let generatedAt: Date
        public let pricePerMtok: Double

        public init(
            report: MeterReport,
            agents: [AgentBreakdown],
            topFiles: [MeterReport.PerFile],
            currentStreak: Int,
            bestStreak: Int,
            activeDaysThisWeek: Int,
            generatedAt: Date = Date(),
            pricePerMtok: Double
        ) {
            self.report = report
            self.agents = agents
            self.topFiles = topFiles
            self.currentStreak = currentStreak
            self.bestStreak = bestStreak
            self.activeDaysThisWeek = activeDaysThisWeek
            self.generatedAt = generatedAt
            self.pricePerMtok = pricePerMtok
        }
    }

    public static func markdown(_ input: Input) -> String {
        let r = input.report
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let generated = dateFormatter.string(from: input.generatedAt)

        let history = r.history ?? []
        let week = history.rollup(windowDays: 7, label: "Last 7 days")
        let month = history.rollup(windowDays: 30, label: "Last 30 days")

        var lines: [String] = []
        lines.append("# DRIP usage report")
        lines.append("")
        lines.append("_Generated \(generated) · DripMeter for macOS_")
        lines.append("")

        // 1. Lifetime totals
        lines.append("## Lifetime totals")
        lines.append("")
        lines.append("| Metric | Value |")
        lines.append("| --- | --- |")
        lines.append("| Tokens saved | **\(formatInt(r.tokensSaved))** |")
        lines.append("| Tokens full / sent | \(formatInt(r.tokensFull)) / \(formatInt(r.tokensSent)) |")
        lines.append("| Reduction | \(r.reductionPct) % |")
        lines
            .append(
                "| Dollars saved | \(formatDollars(r.dollarsSaved)) (@ $\(String(format: "%.2f", input.pricePerMtok))/Mtok) |"
            )
        lines.append("| CO₂ saved | \(String(format: "%.1f", r.co2GSaved)) g |")
        lines.append("| Files tracked | \(formatInt(r.filesTracked)) |")
        lines.append("| Total reads | \(formatInt(r.totalReads)) |")
        if r.totalEdits > 0 {
            lines.append("| Files edited / total edits | \(formatInt(r.filesEdited)) / \(formatInt(r.totalEdits)) |")
        }
        if let compaction = r.compaction, compaction.totalCompactions > 0 {
            lines
                .append(
                    "| Compactions | \(formatInt(compaction.totalCompactions)) (re-sent \(formatInt(compaction.tokensResentAfterCompaction)) tok) |"
                )
        }
        lines.append("")

        // 2. Streak
        lines.append("## Streak")
        lines.append("")
        lines.append("- Current streak: **\(input.currentStreak) day\(input.currentStreak == 1 ? "" : "s")**")
        lines.append("- Best ever: **\(input.bestStreak) day\(input.bestStreak == 1 ? "" : "s")**")
        lines.append("- Active days this week (Mon–Sun): **\(input.activeDaysThisWeek)/7**")
        lines.append("")

        // 3. Last 7 days
        lines.append("## Last 7 days")
        lines.append("")
        lines.append("- Total saved: **\(formatInt(week.tokensSaved))**")
        lines.append("- Daily average: **\(formatInt(week.avgPerDay))**")
        lines.append("- Peak day: \(peakLine(week))")
        lines.append("- Active days: \(week.activeDays)/\(week.windowDays)")
        lines.append("")
        appendTable(&lines, buckets: week.buckets)

        // 4. Last 30 days
        lines.append("## Last 30 days")
        lines.append("")
        lines.append("- Total saved: **\(formatInt(month.tokensSaved))**")
        lines.append("- Daily average: **\(formatInt(month.avgPerDay))**")
        lines.append("- Peak day: \(peakLine(month))")
        lines.append("- Active days: \(month.activeDays)/\(month.windowDays)")
        lines.append("")
        appendTable(&lines, buckets: month.buckets)

        // 5. Per-agent
        let activeAgents = input.agents.filter(\.hasActivity)
        if !activeAgents.isEmpty {
            lines.append("## Per-agent breakdown")
            lines.append("")
            lines.append("| Agent | Sessions | Files | Tokens saved | Reduction |")
            lines.append("| --- | --- | --- | --- | --- |")
            for agent in activeAgents {
                lines
                    .append(
                        "| \(agent.agent.displayName) | \(agent.sessions) | \(agent.filesTracked) | \(formatInt(agent.tokensSaved)) | \(agent.reductionPct) % |"
                    )
            }
            lines.append("")
        }

        // 6. Top files (up to 10)
        let top = Array(input.topFiles.prefix(10))
        if !top.isEmpty {
            lines.append("## Top files")
            lines.append("")
            lines.append("| File | Reads | Saved | Reduction |")
            lines.append("| --- | --- | --- | --- |")
            for file in top {
                let display = shortenPath(file.file, maxLength: 50)
                lines
                    .append(
                        "| `\(display)` | \(file.reads) | \(formatInt(file.tokensSaved)) | \(file.reductionPct) % |"
                    )
            }
            lines.append("")
        }

        lines.append("---")
        lines.append("")
        lines
            .append(
                "Generated by [DripMeter](https://github.com/drip-cli/drip-meter-macos), the menu bar companion for [DRIP](https://github.com/drip-cli/drip)."
            )
        return lines.joined(separator: "\n")
    }

    /// Suggested filename for the report. ISO-ish so files sort
    /// chronologically when you accumulate them.
    public static func suggestedFilename(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "DRIP-usage-\(formatter.string(from: date)).md"
    }

    // MARK: - Helpers

    private static func appendTable(_ lines: inout [String], buckets: [MeterReport.DayBucket]) {
        guard !buckets.isEmpty else {
            lines.append("_No activity recorded in this window._")
            lines.append("")
            return
        }
        lines.append("| Day | Reads | Saved | Reduction |")
        lines.append("| --- | --- | --- | --- |")
        // Most-recent first reads better in a report than the chronological
        // order DRIP emits. Reverse the slice.
        for bucket in buckets.reversed() {
            lines
                .append(
                    "| \(bucket.day) | \(bucket.reads) | \(formatInt(bucket.tokensSaved)) | \(bucket.reductionPct) % |"
                )
        }
        lines.append("")
    }

    private static func peakLine(_ stats: PeriodStats) -> String {
        guard let peak = stats.peakDay, peak.tokensSaved > 0 else { return "—" }
        return "\(peak.day) (\(formatInt(peak.tokensSaved)) saved)"
    }

    private static func formatInt(_ n: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private static func formatDollars(_ n: Double) -> String {
        String(format: "$%.2f", n)
    }

    private static func shortenPath(_ path: String, maxLength: Int) -> String {
        guard path.count > maxLength else { return path }
        let tail = String(path.suffix(maxLength - 1))
        return "…\(tail)"
    }
}
