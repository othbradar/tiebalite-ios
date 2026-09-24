#if UITESTING
import SwiftUI

struct DebugR10ComposerGallery: View {
    @Environment(\.textComposer) private var host
    @State private var result = ""
    @State private var preparing = false
    var body: some View {
        List {
            Text("隔离图片样本，不会连接贴吧或发布真实内容。")
            ForEach([1, 4, 5], id: \.self) { count in
                Button("选择 \(count) 张样图") { Task { await open(count: count) } }
                    .disabled(preparing).accessibilityIdentifier("r10.select.\(count)")
            }
            Text(result).accessibilityIdentifier("r10.result")
        }.navigationTitle("图片与表情")
    }

    private func open(count: Int) async {
        preparing = true
        defer { preparing = false }
        let context = AuthContext.active(.init(sessionID: .init(rawValue: 10), generation: 1))
        let service = TextComposerService(repository: FixtureTextWriteRepository(), uploader: FixtureComposerImageUploader(),
                                          imageLoader: ProductionImageLoader.production(), currentContext: { context })
        let target = TextComposeTarget(kind: .threadReply, forumID: 10, forumName: "固定样本", threadID: 101, quote: "图片与表情")
        do {
            var draft = TextDraft()
            for number in 1...count { draft.photos.append(try await Self.photo(number)) }
            service.drafts.save(draft, target: target, context: context)
            host?.present(target, using: service) { _ in result = "模拟完成" }
        } catch { result = "样图读取失败" }
    }

    private static func photo(_ number: Int) async throws -> ComposerPhoto {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240))
        let bytes = renderer.jpegData(withCompressionQuality: 0.95) { context in
            UIColor(hue: CGFloat(number) / 7, saturation: 0.4, brightness: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
            "\(number)".draw(at: CGPoint(x: 140, y: 90), withAttributes: [.font: UIFont.systemFont(ofSize: 48)])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r10-sample-\(number).jpg")
        try bytes.write(to: url)
        return try await ComposerPhotoPreparation.shared.prepare(file: ComposerPhotoFile(url: url))
    }
}
#endif
