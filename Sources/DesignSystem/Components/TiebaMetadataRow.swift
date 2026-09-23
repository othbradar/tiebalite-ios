import SwiftUI

struct TiebaFlatDivider: View {
    var inset: CGFloat = TiebaParityTokens.horizontalInset

    var body: some View {
        Rectangle()
            .fill(TiebaParityTokens.divider)
            .frame(height: 1)
            .padding(.horizontal, inset)
            .accessibilityHidden(true)
    }
}

struct TiebaMetadataRow: View {
    let values: [String]
    @ScaledMetric(relativeTo: .caption2) private var fontSize: CGFloat = 11

    var body: some View {
        Text(values.filter { !$0.isEmpty }.joined(separator: " · "))
            .font(.system(size: fontSize))
            .foregroundStyle(SemanticColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TiebaUserLevelBadge: View {
    let level: Int?
    @ScaledMetric(relativeTo: .caption2) private var fontSize: CGFloat = 9

    var body: some View {
        if let level, level > 0 {
            Text("\(level)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(TiebaParityTokens.userLevelColor(level))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(TiebaParityTokens.userLevelColor(level).opacity(0.25), in: Capsule())
                .fixedSize()
                .accessibilityLabel("用户等级 \(level)")
        }
    }
}

struct TiebaForumLevelBadge: View {
    let level: Int?
    @ScaledMetric(relativeTo: .caption2) private var fontSize: CGFloat = 11

    var body: some View {
        if let level, level > 0 {
            Text("Lv.\(level)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(SemanticColor.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 3))
                .fixedSize()
                .accessibilityLabel("吧等级 \(level)")
        }
    }
}

struct TiebaFeedRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(TiebaParityTokens.neutralFill)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    bar(width: 80, height: 10)
                    bar(width: 112, height: 7)
                }
            }
            bar(width: 180, height: 12)
            Rectangle().fill(TiebaParityTokens.neutralFill).frame(height: 9)
            HStack {
                bar(width: 40, height: 8)
                Spacer()
                bar(width: 32, height: 8)
                Spacer()
                bar(width: 32, height: 8)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("信息流正在加载")
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Rectangle().fill(TiebaParityTokens.neutralFill).frame(width: width, height: height)
    }
}
