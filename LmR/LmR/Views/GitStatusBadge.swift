import SwiftUI

extension GitState {
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .checking: return .gray
        case .clean: return .green
        case .dirty: return .orange
        case .error: return .red
        }
    }

    var help: String {
        switch self {
        case .unknown: return "Git status unknown"
        case .checking: return "Checking git status…"
        case .clean: return "Working tree clean"
        case .dirty: return "Working tree has uncommitted changes"
        case .error: return "Could not read git status"
        }
    }
}

/// Branch + clean/dirty dot, with optional ahead/behind and last-commit info.
/// Ahead/behind counts are card-only (`showsAheadBehind`); last-commit subject
/// is shown in both the card and the compact list row — on its own line in
/// the card, inline with the branch in the row (`lastCommitInline`) to keep
/// the row a single line tall. The commit hover tooltip differs by context:
/// the card shows the full when/who detail, the row shows just the committer
/// (the row's title already covers the repo path on hover).
struct GitStatusBadge: View {
    let status: GitStatusInfo
    var showsAheadBehind: Bool = false
    var lastCommitInline: Bool = false

    @State private var pulsate: Bool = false

    var body: some View {
        if lastCommitInline {
            HStack(spacing: 6) {
                dot
                branchLabel
                if let aheadBehind = showsAheadBehind ? aheadBehindLabel : nil {
                    Text(aheadBehind)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                lastCommitLabelView
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    dot
                    branchLabel
                    if let aheadBehind = showsAheadBehind ? aheadBehindLabel : nil {
                        Text(aheadBehind)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                lastCommitLabelView
            }
        }
    }

    @ViewBuilder
    private var branchLabel: some View {
        if let branch = status.branch {
            Text(branch)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var lastCommitLabelView: some View {
        if let subject = status.lastCommitSubject {
            Text(lastCommitLabel(subject: subject))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(lastCommitInline ? committerTooltip : lastCommitTooltip(subject: subject))
        } else if status.state == .clean || status.state == .dirty {
            Text("No commits yet")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    private var dot: some View {
        Circle()
            .fill(status.state.color)
            .frame(width: 8, height: 8)
            .opacity(status.state == .checking ? (pulsate ? 0.3 : 1.0) : 1.0)
            .animation(
                status.state == .checking
                    ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                    : .default,
                value: pulsate
            )
            .onAppear { pulsate = status.state == .checking }
            .onChange(of: status.state) { _, newValue in
                pulsate = newValue == .checking
            }
            .help(status.state.help)
    }

    private var aheadBehindLabel: String? {
        guard status.ahead > 0 || status.behind > 0 else { return nil }
        var parts: [String] = []
        if status.ahead > 0 { parts.append("↑\(status.ahead)") }
        if status.behind > 0 { parts.append("↓\(status.behind)") }
        return parts.joined(separator: " ")
    }

    private func lastCommitLabel(subject: String) -> String {
        guard let date = status.lastCommitRelativeDate else { return subject }
        return "\(subject) · \(date)"
    }

    private var committerTooltip: String {
        status.lastCommitAuthorName.map { "By \($0)" } ?? "Unknown committer"
    }

    private func lastCommitTooltip(subject: String) -> String {
        var lines = [subject]
        if let absoluteDate = status.lastCommitAbsoluteDate {
            lines.append("When: \(absoluteDate)")
        }
        if let authorName = status.lastCommitAuthorName {
            lines.append("By: \(authorName)")
        }
        return lines.joined(separator: "\n")
    }
}
