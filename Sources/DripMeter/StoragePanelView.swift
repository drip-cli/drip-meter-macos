import DripMeterCore
import SwiftUI

/// Storage stats card. Shown in Settings → Advanced. Surface what `drip
/// cache stats` would show in the terminal — DB size, cache files,
/// dedup savings, and how many bytes a `drip cache compact` would
/// reclaim.
struct StoragePanelView: View {
    let storage: MeterReport.Storage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(byteFormatter.string(fromByteCount: storage.totalBytes))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text("on disk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if storage.compactableBytes > 0 {
                    Text("\(byteFormatter.string(fromByteCount: storage.compactableBytes)) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    cell("DB", value: byteFormatter.string(fromByteCount: storage.dbSizeBytes))
                    cell("Cache files", value: "\(storage.cacheFiles)")
                }
                GridRow {
                    cell("Cache size", value: byteFormatter.string(fromByteCount: storage.cacheSizeBytes))
                    cell("Inline rows", value: "\(storage.inlineRows)")
                }
                GridRow {
                    cell("Unique blobs", value: "\(storage.uniqueHashes)")
                    cell("Dedup saved", value: byteFormatter.string(fromByteCount: storage.dedupSavings))
                }
                if storage.orphanFiles > 0 {
                    GridRow {
                        cell("Orphan files", value: "\(storage.orphanFiles)")
                        cell("Orphan bytes", value: byteFormatter.string(fromByteCount: storage.orphanBytes))
                    }
                }
            }
        }
    }

    private func cell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var byteFormatter: ByteCountFormatter {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        f.includesUnit = true
        return f
    }
}
