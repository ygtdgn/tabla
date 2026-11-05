import CoreGraphics

/// Windows-11 tarzı panel yerleşimi: kartlar tek satırda başlar, sığmazsa
/// satırlara sarar ve önizleme yüksekliği küçülerek her şey ekrana sığdırılır.
/// Tüm çerçeveler panel koordinatındadır, orijin sol-üsttür.
public enum SwitcherLayout {
    public static let maxThumbHeight: CGFloat = 180
    public static let minThumbHeight: CGFloat = 60
    public static let step: CGFloat = 10
    public static let titleHeight: CGFloat = 18
    public static let titleSpacing: CGFloat = 4
    public static let cardPadding: CGFloat = 8
    public static let spacing: CGFloat = 10
    public static let panelPadding: CGFloat = 14
    public static let minAspect: CGFloat = 0.6
    public static let maxAspect: CGFloat = 2.0

    public struct Result: Equatable, Sendable {
        public let cardFrames: [CGRect]
        public let thumbFrames: [CGRect]
        public let panelSize: CGSize
        public let thumbHeight: CGFloat
    }

    public static func compute(aspectRatios: [CGFloat], maxPanelSize: CGSize) -> Result {
        guard !aspectRatios.isEmpty else {
            return Result(cardFrames: [], thumbFrames: [], panelSize: .zero, thumbHeight: maxThumbHeight)
        }
        var h = maxThumbHeight
        while h > minThumbHeight, !fits(aspectRatios, h, maxPanelSize) { h -= step }
        return layout(aspectRatios, h, maxPanelSize.width - 2 * panelPadding)
    }

    private static func fits(_ aspects: [CGFloat], _ h: CGFloat, _ maxPanel: CGSize) -> Bool {
        layout(aspects, h, maxPanel.width - 2 * panelPadding).panelSize.height <= maxPanel.height
    }

    private static func layout(_ aspects: [CGFloat], _ h: CGFloat, _ availableWidth: CGFloat) -> Result {
        let thumbWidths = aspects.map { min(max(h * $0, minAspect * h), maxAspect * h) }
        let cardHeight = h + titleHeight + titleSpacing + 2 * cardPadding

        // Açgözlü satır dizilimi (kart indeksleri).
        var rows: [[Int]] = []
        var rowWidth: CGFloat = 0
        for (i, tw) in thumbWidths.enumerated() {
            let cw = tw + 2 * cardPadding
            if let last = rows.last, !last.isEmpty, rowWidth + spacing + cw <= availableWidth {
                rows[rows.count - 1].append(i)
                rowWidth += spacing + cw
            } else {
                rows.append([i])
                rowWidth = cw
            }
        }
        let rowWidths = rows.map { row in
            row.reduce(CGFloat(0)) { $0 + thumbWidths[$1] + 2 * cardPadding } + CGFloat(row.count - 1) * spacing
        }
        let widest = rowWidths.max() ?? 0
        let panelWidth = widest + 2 * panelPadding
        let panelHeight = CGFloat(rows.count) * cardHeight + CGFloat(rows.count - 1) * spacing + 2 * panelPadding

        var cards = [CGRect](repeating: .zero, count: aspects.count)
        var thumbs = [CGRect](repeating: .zero, count: aspects.count)
        for (r, row) in rows.enumerated() {
            var x = panelPadding + (widest - rowWidths[r]) / 2
            let y = panelPadding + CGFloat(r) * (cardHeight + spacing)
            for i in row {
                let cw = thumbWidths[i] + 2 * cardPadding
                cards[i] = CGRect(x: x, y: y, width: cw, height: cardHeight)
                thumbs[i] = CGRect(x: x + cardPadding,
                                   y: y + cardPadding + titleHeight + titleSpacing,
                                   width: thumbWidths[i], height: h)
                x += cw + spacing
            }
        }
        return Result(cardFrames: cards, thumbFrames: thumbs,
                      panelSize: CGSize(width: panelWidth, height: panelHeight), thumbHeight: h)
    }
}
