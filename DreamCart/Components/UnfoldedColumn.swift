import SwiftUI

/// The screens before the app proper (splash, welcome, the onboarding offer)
/// are one phone column. Unfolded, the column takes the trailing pane and the
/// brand fills the leading one, so nothing sits under the fold. Everywhere
/// else this is just the column.
struct UnfoldedColumn<Content: View>: View {
    /// The splash already shows the mark, so its brand pane stays plain.
    var showsMark = true
    @ViewBuilder let content: Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { proxy in
            let split = UnfoldedSplit.make(width: proxy.size.width,
                                           isRegularWidth: sizeClass == .regular,
                                           fold: proxy.verticalFold())
            ZStack(alignment: .topLeading) {
                // Folded, the brand pane is not built: a zero-width copy still
                // reached accessibility, centred off the leading edge.
                if let split {
                    brandPane
                        .frame(width: split.primaryWidth)
                        .frame(maxHeight: .infinity)
                }
                content
                    .environment(\.horizontalSizeClass, split == nil ? sizeClass : .compact)
                    .frame(maxWidth: split?.secondaryWidth ?? .infinity, maxHeight: .infinity)
                    .padding(.leading, split?.secondaryX ?? 0)
            }
        }
    }

    private var brandPane: some View {
        ZStack {
            Theme.candy.ignoresSafeArea()
            if showsMark {
                VStack(spacing: 18) {
                    BagMark(size: 92)
                    Text("DreamCart")
                        .font(.dcHero)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
