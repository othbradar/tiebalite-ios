import SwiftUI

struct TiebaMediaGridGeometry {
    let rowCounts: [Int]
    let frames: [CGRect]
    let height: CGFloat

    static func proposedWidth(_ width: CGFloat?) -> CGFloat {
        guard let width, width.isFinite else { return 320 }
        return max(0, width)
    }

    init(count: Int, width: CGFloat, aspectRatios: [Double]? = nil) {
        guard count > 0, width.isFinite, width > 0 else {
            rowCounts = []
            frames = []
            height = 0
            return
        }
        let count = min(8, count)
        let columns = count == 4 ? 2 : min(count, 3)
        let rows = (count + columns - 1) / columns
        let gap = min(TiebaParityTokens.imageGap, width / CGFloat(columns))
        let cellWidth = max(0, (width - CGFloat(columns - 1) * gap) / CGFloat(columns))
        let cellHeight = count == 1 ? width / 2 : (count <= 3 ? width / 3 : cellWidth)
        rowCounts = (0..<rows).map { min(columns, count - $0 * columns) }
        if let aspectRatios, aspectRatios.count >= count {
            var result: [CGRect] = []
            var offset = 0
            var y: CGFloat = 0
            for rowCount in rowCounts {
                let ratios = aspectRatios[offset..<(offset + rowCount)].map {
                    $0.isFinite && $0 > 0 ? CGFloat($0) : 1
                }
                let availableWidth = cellWidth * CGFloat(rowCount)
                let rowHeight = availableWidth / ratios.reduce(0, +)
                var x: CGFloat = 0
                for ratio in ratios {
                    let itemWidth = rowHeight * ratio
                    result.append(CGRect(x: x, y: y, width: itemWidth, height: rowHeight))
                    x += itemWidth + gap
                }
                y += rowHeight + gap
                offset += rowCount
            }
            frames = result
            height = max(0, y - gap)
            return
        }
        frames = (0..<count).map { index in
            CGRect(
                x: CGFloat(index % columns) * (cellWidth + gap),
                y: CGFloat(index / columns) * (cellHeight + gap),
                width: cellWidth,
                height: cellHeight
            )
        }
        height = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * gap
    }
}

private struct TiebaMediaGridLayout: Layout {
    var aspectRatios: [Double]?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = TiebaMediaGridGeometry.proposedWidth(proposal.width)
        let geometry = TiebaMediaGridGeometry(count: subviews.count, width: width, aspectRatios: aspectRatios)
        return CGSize(width: width, height: geometry.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let geometry = TiebaMediaGridGeometry(count: subviews.count, width: bounds.width, aspectRatios: aspectRatios)
        for (subview, frame) in zip(subviews, geometry.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}

struct TiebaMediaGrid: View {
    let resources: [ImageResourceDescriptor]
    let imageLoader: any ImageLoading

    /// Hosts existing image cells without owning their loading or selection lifecycle.
    static func content<Content: View>(
        aspectRatios: [Double], @ViewBuilder cells: () -> Content
    ) -> some View {
        TiebaMediaGridLayout(aspectRatios: aspectRatios) { cells() }
    }

    var body: some View {
        TiebaMediaGridLayout {
            ForEach(visibleResources, id: \.resourceID) { resource in
                TiebaRemoteImageView(
                    resource: resource,
                    imageLoader: imageLoader,
                    purpose: .listThumbnail,
                    accessibilityLabel: "图片"
                )
                .accessibilityIdentifier("tieba.media-grid.\(resource.resourceID)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var visibleResources: [ImageResourceDescriptor] {
        var seen: Set<String> = []
        return Array(resources.filter { seen.insert($0.resourceID).inserted }.prefix(8))
    }
}
