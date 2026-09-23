/// Display fields from Personalized. Missing scalar data never receives fixture values.
struct RecommendationFeedDetails: Equatable, Sendable {
    var abstractText = ""
    var showsTitle = true
    var timeUnixSeconds: UInt32?
    var media: [ImageResourceDescriptor] = []
    var totalMediaCount = 0
    var agreeCount: Int64?
    var shareCount: Int64?
}

extension RecommendationSummary {
    var mediaResources: [ImageResourceDescriptor] {
        feed.media.isEmpty ? thumbnail.map { [$0.resource] } ?? [] : feed.media
    }

    var previewMediaResources: [ImageResourceDescriptor] {
        Array(mediaResources.prefix(3))
    }

    var mediaCount: Int {
        max(feed.totalMediaCount, mediaResources.count)
    }
}
