import AppKit
import Observation
import SwiftUI

/// One window card. Frames are in panel coordinates with a top-left origin (SwitcherLayout).
struct SwitcherCard: Identifiable {
    let id: CGWindowID
    let title: String
    let icon: NSImage
    let frame: CGRect
    let thumbSize: CGSize
    var image: CGImage?
}

@MainActor @Observable
final class SwitcherViewModel {
    private(set) var cards: [SwitcherCard] = []
    var selectedIndex = 0

    func present(_ cards: [SwitcherCard]) {
        self.cards = cards
    }

    /// Ignores windows that are no longer shown.
    func setImage(_ image: CGImage, for id: CGWindowID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].image = image
    }

    func clear() {
        cards = []
    }
}

/// Option+Tab panel content (design A): cards at their layout positions, selected card in blue.
struct SwitcherView: View {
    static let selectionColor = Color(red: 0.30, green: 0.55, blue: 1.0)
    static let cardCornerRadius: CGFloat = 10

    let model: SwitcherViewModel
    let onClick: (Int) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.cards.enumerated()), id: \.element.id) { index, card in
                SwitcherCardView(card: card, isSelected: index == model.selectedIndex)
                    .contentShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius))
                    .onTapGesture { onClick(index) }
                    .offset(x: card.frame.minX, y: card.frame.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SwitcherCardView: View {
    static let iconSize: CGFloat = 14
    static let fallbackIconSize: CGFloat = 64
    static let thumbCornerRadius: CGFloat = 6

    let card: SwitcherCard
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SwitcherLayout.titleSpacing) {
            HStack(spacing: 6) {
                Image(nsImage: card.icon)
                    .resizable()
                    .frame(width: Self.iconSize, height: Self.iconSize)
                Text(card.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: SwitcherLayout.titleHeight)

            preview
                .frame(width: card.thumbSize.width, height: card.thumbSize.height)
        }
        .padding(SwitcherLayout.cardPadding)
        .frame(width: card.frame.width, height: card.frame.height, alignment: .topLeading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: SwitcherView.cardCornerRadius)
                    .fill(SwitcherView.selectionColor.opacity(0.18))
                RoundedRectangle(cornerRadius: SwitcherView.cardCornerRadius)
                    .strokeBorder(SwitcherView.selectionColor, lineWidth: 2)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = card.image {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Self.thumbCornerRadius))
        } else {
            // Kept inside small thumbnails (the layout can shrink them below 64 pt).
            let side = min(Self.fallbackIconSize, card.thumbSize.width, card.thumbSize.height)
            Image(nsImage: card.icon)
                .resizable()
                .frame(width: side, height: side)
        }
    }
}
