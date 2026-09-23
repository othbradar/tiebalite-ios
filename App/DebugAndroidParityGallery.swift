#if DEBUG
import SwiftUI

/// Offline gallery transport; the production loader still fetches, validates,
/// downsamples and caches every sample. No secondary network session or image cache.
private actor DebugR01GalleryTransport: HTTPDataLoading {
    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = request.url, url.host == "r01.fixture.invalid" else {
            throw URLError(.resourceUnavailable)
        }
        if url.lastPathComponent == "loading" {
            // Await cancellation without a clock, retry loop or artificial delay.
            let stream = AsyncStream<Void> { _ in }
            for await _ in stream { try Task.checkCancellation() }
            throw CancellationError()
        }
        guard let data = DebugR01ImageSamples.data(for: url.lastPathComponent),
              data.count <= maximumByteCount,
              let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"]
              ) else { throw URLError(.resourceUnavailable) }
        return (data, response)
    }
}

struct DebugAndroidParityGallery: View {
    @State private var loader = ProductionImageLoader(loader: DebugR01GalleryTransport())
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Android parity · R01")
                .font(.headline)
            Text("本地展示样本 · 不代表 Live 数据")
                .font(.caption2)
                .foregroundStyle(SemanticColor.secondaryText)
            avatars
            levels
            forum
            TiebaFlatDivider(inset: 0)
            overview
                .frame(maxWidth: 340, alignment: .leading)
            Text("平面 feed row skeleton").font(.caption2)
            TiebaFeedRowSkeleton()
            TiebaFlatDivider(inset: 0)
            Text("原宽网格 · 1–8 张").font(.headline)
            ForEach(1...8, id: \.self) { count in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(count) 张").font(.caption)
                    TiebaMediaGrid(resources: resources(count: count), imageLoader: loader)
                }
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gallery.android-parity")
    }

    private var avatars: some View {
        HStack(spacing: 16) {
            avatarSample("成功", key: "user")
            avatarSample("加载", key: "loading")
            avatarSample("失败", key: "failed")
            Spacer(minLength: 0)
        }
    }

    private func avatarSample(_ title: String, key: String) -> some View {
        HStack(spacing: 6) {
            TiebaAvatarView(resource: resource(key), imageLoader: loader)
                .accessibilityIdentifier("gallery.avatar.\(key)")
            Text(title).font(.system(size: labelSize))
        }
    }

    private var levels: some View {
        HStack(spacing: 12) {
            Text("用户等级").font(.system(size: labelSize))
            ForEach([1, 8, 14, 18], id: \.self) { level in
                TiebaUserLevelBadge(level: level)
            }
        }
    }

    private var forum: some View {
        HStack(spacing: 14) {
            TiebaForumAvatarView(resource: resource("forum"), imageLoader: loader)
            VStack(alignment: .leading, spacing: 2) {
                Text("战列舰").font(.subheadline.bold())
                TiebaMetadataRow(values: ["热度 2.9W", "成员 12.8W"])
            }
            Spacer(minLength: 0)
            TiebaForumLevelBadge(level: 14)
        }
    }

    private var overview: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach((row * 3 + 1)...min(8, row * 3 + 3), id: \.self) { count in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(count) 张").font(.caption2)
                            TiebaMediaGrid(resources: resources(count: count), imageLoader: loader)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityIdentifier("gallery.grid.\(count)")
                    }
                }
            }
        }
    }

    private func resource(_ key: String) -> ImageResourceDescriptor {
        ImageResourceDescriptor(
            resourceID: "gallery.\(key)",
            candidateURLs: ["https://r01.fixture.invalid/\(key)"]
        )
    }

    private func resources(count: Int) -> [ImageResourceDescriptor] {
        (1...count).map { index in
            ImageResourceDescriptor(
                resourceID: "gallery.grid\(count).media\(index)",
                candidateURLs: ["https://r01.fixture.invalid/media\((index - 1) % 3 + 1)"]
            )
        }
    }
}
#endif
