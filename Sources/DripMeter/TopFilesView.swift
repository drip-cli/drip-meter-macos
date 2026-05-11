import DripMeterCore
import SwiftUI

/// Top-N files by tokens saved. Mirrors the table `drip meter` prints in the
/// terminal — the actual ranking comes from `meter.top`, so we don't need to
/// re-sort here.
struct TopFilesView: View {
    let files: [MeterReport.PerFile]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top files")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            VStack(spacing: 4) {
                ForEach(files) { file in
                    TopFileRow(file: file)
                }
            }
        }
    }
}

private struct TopFileRow: View {
    let file: MeterReport.PerFile

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DripFormatter.shortenPath(file.file))
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                Text("\(file.reads) reads")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DripFormatter.compactInteger(file.tokensSaved))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                ReductionBar(percent: file.reductionPct)
                    .frame(width: 60, height: 4)
            }
        }
    }
}

private struct ReductionBar: View {
    let percent: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.18))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DripPalette.green)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, percent))) / 100)
            }
        }
    }
}
