import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ComposerPickedPhoto: Transferable {
    let file: ComposerPhotoFile
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("composer-import-\(UUID().uuidString)")
            try FileManager.default.copyItem(at: received.file, to: url)
            return ComposerPickedPhoto(file: ComposerPhotoFile(url: url))
        }
    }
}

struct ComposerPhotoGrid: View {
    let photos: [ComposerPhoto]
    let loader: any ImageLoading
    let remove: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(photos) { photo in
                ComposerPhotoThumbnail(photo: photo, loader: loader, remove: { remove(photo.id) })
            }
        }
        .padding(.horizontal, 16).accessibilityElement(children: .contain).accessibilityIdentifier("composer.photos")
    }
}

private struct ComposerPhotoThumbnail: View {
    let photo: ComposerPhoto
    let loader: any ImageLoading
    let remove: () -> Void
    @State private var image: UIImage?
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(TiebaParityTokens.neutralFill)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28).background(.background.opacity(0.9))
                    .frame(width: 44, height: 44, alignment: .topTrailing)
            }
            .buttonStyle(.plain).accessibilityLabel("删除图片")
            .accessibilityIdentifier("composer.photo.remove.\(photo.id)")
        }
        .frame(height: 64).clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composer.photo.\(photo.id)")
        .task(id: photo.id) {
            do {
                let payload = try await loader.loadLocalPhoto(photo)
                try Task.checkCancellation()
                image = payload.displayImage()
            } catch { image = nil }
        }
    }
}

struct ComposerEmoticonPanel: View {
    let insert: (TiebaEmoticon) -> Void
    private let emoticons = TiebaEmoticonRegistry.catalog.filter {
        TiebaEmoticonRegistry.named($0.name)?.resourceID == $0.resourceID
    }
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 0)], spacing: 0) {
                ForEach(emoticons, id: \.resourceID) { emoticon in
                    Button { insert(emoticon) } label: {
                        if let image = TiebaRichTextBuilder.image(resourceID: emoticon.resourceID) {
                            Image(uiImage: image).resizable().scaledToFit().padding(8).frame(width: 48, height: 48)
                        }
                    }
                    .buttonStyle(.plain).accessibilityLabel(emoticon.name)
                    .accessibilityIdentifier("composer.emoticon.\(emoticon.resourceID)")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        .background(TiebaParityTokens.neutralFill)
        .accessibilityIdentifier("composer.emoticons")
    }
}
