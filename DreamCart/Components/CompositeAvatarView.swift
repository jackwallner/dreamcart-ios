import SwiftUI
import UIKit

// Renders the dressing-room avatar by layering on-device garment cutouts over a
// stylized body, ordered by slot. No network, no per-outfit AI generation — the
// only cost is a one-time Vision segmentation per product, cached forever.
struct CompositeAvatarView: View {
    let look: AvatarLook
    let picks: [String: Product]          // slot -> chosen piece
    @Environment(\.colorScheme) private var scheme
    @State private var cutouts: [String: UIImage] = [:]   // productId -> cutout
    @State private var failedCutouts: Set<String> = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                bodyBase(geo.size)
                ForEach(placedSlots, id: \.slot) { entry in
                    if let product = picks[entry.slot] {
                        piece(product, entry.placement, in: geo.size)
                            .zIndex(entry.placement.z)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: pickKey) { await loadCutouts() }
    }

    // Slots that actually have a piece, ordered back-to-front.
    private var placedSlots: [(slot: String, placement: SlotPlacement)] {
        SlotPlacement.bySlot
            .filter { picks[$0.key] != nil }
            .map { (slot: $0.key, placement: $0.value) }
            .sorted { $0.placement.z < $1.placement.z }
    }

    private var pickKey: [String: String] { picks.mapValues(\.id) }

    @ViewBuilder
    private func piece(_ product: Product, _ p: SlotPlacement, in size: CGSize) -> some View {
        Group {
            if let cut = cutouts[product.id] {
                Image(uiImage: cut).resizable().scaledToFit()
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if failedCutouts.contains(product.id) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.dcIconM)
                    .foregroundStyle(Theme.subtle(scheme))
            } else {
                ProgressView()
                    .tint(Theme.violet)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
                    .accessibilityLabel("Preparing \(product.name)")
            }
        }
        .frame(width: size.width * p.w, height: size.height * p.h)
        .position(x: size.width * p.cx, y: size.height * p.cy)
    }

    // A simple tinted figure so the pieces read as "worn," not floating.
    private func bodyBase(_ size: CGSize) -> some View {
        Image(systemName: "figure.stand")
            .resizable().scaledToFit()
            .frame(height: size.height * 0.94)
            .foregroundStyle(look.skinTint.opacity(scheme == .dark ? 0.5 : 0.32))
            .position(x: size.width * 0.5, y: size.height * 0.52)
    }

    private func loadCutouts() async {
        for product in picks.values where cutouts[product.id] == nil {
            if let img = await AvatarCutoutCache.shared.cutout(for: product) {
                withAnimation(.easeOut(duration: 0.25)) { cutouts[product.id] = img }
            } else {
                failedCutouts.insert(product.id)
            }
        }
    }
}

extension AvatarLook {
    // Body tint per look — a light differentiator until real body art lands.
    var skinTint: Color {
        switch self {
        case .aria: return Color(red: 0.83, green: 0.62, blue: 0.50)
        case .maya: return Color(red: 0.55, green: 0.38, blue: 0.29)
        case .zoe:  return Color(red: 0.92, green: 0.78, blue: 0.68)
        case .kai:  return Color(red: 0.72, green: 0.52, blue: 0.40)
        case .leo:  return Color(red: 0.62, green: 0.44, blue: 0.34)
        case .rio:  return Color(red: 0.88, green: 0.72, blue: 0.62)
        }
    }
}
