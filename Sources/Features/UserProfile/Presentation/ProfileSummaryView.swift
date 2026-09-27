import SwiftUI

struct ProfileSummaryView: View {
    let profile: UserProfile?
    let title: String
    let subtitle: String?
    let imageLoader: any ImageLoading
    @ScaledMetric(relativeTo: .headline) private var nameSize = 20.0

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName ?? title)
                    .font(.system(size: nameSize, weight: .bold))
                    .foregroundStyle(SemanticColor.primaryText)
                    .accessibilityIdentifier("personal.account.name")
                if let introduction = profile?.introduction ?? subtitle, !introduction.isEmpty {
                    Text(introduction).font(.caption).foregroundStyle(SemanticColor.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TiebaAvatarView(resource: profile.flatMap {
                TiebaAvatarResource.user(userID: $0.userID.rawValue, portrait: $0.portraitResourceID)
            }, imageLoader: imageLoader, size: 56)
            .accessibilityIdentifier("personal.account.avatar")
        }
        .padding(.vertical, 24)
        .contentShape(Rectangle())
    }
}

struct ProfileStatisticsView: View {
    let profile: UserProfile
    @ScaledMetric(relativeTo: .headline) private var countSize = 20.0

    private var values: [(String, Int)] {
        [("关注", profile.followingCount), ("粉丝", profile.followerCount), ("回贴", profile.postCount)]
            .compactMap { title, count in count.map { (title, $0) } }
    }

    var body: some View {
        if !values.isEmpty {
            HStack(spacing: 0) {
                ForEach(values, id: \.0) { item in
                    if item.0 != values.first?.0 {
                        Rectangle().fill(SemanticColor.separator).frame(width: 1, height: 20)
                    }
                    VStack(spacing: 2) {
                        Text(item.1.formatted(.number.locale(Locale(identifier: "zh_CN")).grouping(.never)))
                            .font(.system(size: countSize, weight: .bold, design: .rounded))
                            .foregroundStyle(SemanticColor.primaryText)
                        Text(item.0).font(.caption).foregroundStyle(SemanticColor.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("personal.stat.\(item.0)")
                }
            }
            .padding(.vertical, 18)
            .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 16)
        }
    }
}
