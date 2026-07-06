import SwiftUI

// Nuuly-style styling: pick one piece per slot from your closet, save the look.
struct OutfitBuilderView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme

    // Slot order top-to-bottom, matching the closet_items.slot values.
    private let slots: [(key: String, label: String, icon: String)] = [
        ("headwear", "Hat", "hat.widebrim"),
        ("eyewear", "Shades", "sunglasses"),
        ("jewelry", "Jewelry", "sparkle"),
        ("outerwear", "Outerwear", "coat"),
        ("top", "Top", "tshirt"),
        ("bottom", "Bottom", "figure.walk"),
        ("footwear", "Shoes", "shoe"),
        ("bag", "Bag", "bag"),
        ("accessory", "Extra", "scribble.variable"),
    ]

    @State private var picks: [String: Product] = [:]
    @State private var pickingSlot: SlotID? = nil
    @State private var name = ""
    @State private var savedFlash = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if shop.closet.isEmpty {
                    EmptyState(icon: "hanger", title: "Nothing to style yet",
                               message: "Buy a few pieces, then come back to build looks.")
                        .padding(.top, 40)
                } else {
                    lookPreview
                    slotList
                    saveRow
                    if !shop.outfits.isEmpty { savedLooks }
                }
            }
            .padding(16)
        }
        .background(Theme.bg(scheme))
        .navigationTitle("Style a look")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickingSlot) { slot in
            SlotPickerSheet(slot: slot.id,
                            options: shop.closet.filter { $0.slot == slot.id }) { chosen in
                picks[slot.id] = chosen
                pickingSlot = nil
                Haptics.soft()
            }
        }
    }

    private var chosen: [Product] { slots.compactMap { picks[$0.key] } }

    private var lookPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.corner)
                .fill(Theme.candy.opacity(0.12))
            if chosen.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wand.and.stars").font(.system(size: 34)).foregroundStyle(Theme.violet)
                    Text("Tap a slot to start styling")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.subtle(scheme))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chosen) { p in
                            RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                                .frame(width: 96, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(height: 160)
    }

    private var slotList: some View {
        VStack(spacing: 10) {
            ForEach(slots, id: \.key) { slot in
                let available = shop.closet.contains { $0.slot == slot.key }
                Button {
                    if available { Haptics.tap(); pickingSlot = SlotID(id: slot.key) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: slot.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(available ? Theme.violet : Theme.subtle(scheme).opacity(0.4))
                            .frame(width: 26)
                        Text(slot.label)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(available ? Theme.ink(scheme) : Theme.subtle(scheme).opacity(0.5))
                        Spacer()
                        if let p = picks[slot.key] {
                            Text(p.name).font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.subtle(scheme)).lineLimit(1)
                            RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                                .frame(width: 34, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        } else if available {
                            Text("Choose").font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.violet)
                        } else {
                            Text("None owned").font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .cardStyle(scheme)
                }
                .buttonStyle(.plain)
                .disabled(!available)
            }
        }
    }

    private var saveRow: some View {
        VStack(spacing: 10) {
            TextField("Name this look", text: $name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(14)
                .cardStyle(scheme)
            CandyButton(title: savedFlash ? "Saved!" : "Save look", systemImage: "square.and.arrow.down.fill",
                        enabled: !picks.isEmpty) {
                Task {
                    let items = picks.mapValues { $0.id }
                    let ok = await shop.saveOutfit(name: name.isEmpty ? "My Look" : name, items: items)
                    if ok {
                        savedFlash = true; picks = [:]; name = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
                    }
                }
            }
        }
    }

    private var savedLooks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Saved looks")
            ForEach(shop.outfits) { outfit in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(outfit.name).font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink(scheme))
                        Spacer()
                        Button {
                            Task { await shop.deleteOutfit(outfit.id) }
                        } label: {
                            Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(Theme.subtle(scheme))
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(outfit.outfitItems ?? [], id: \.productId) { item in
                                if let p = item.products {
                                    RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                                        .frame(width: 60, height: 74)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .cardStyle(scheme)
            }
        }
    }
}

struct SlotID: Identifiable { let id: String }

struct SlotPickerSheet: View {
    let slot: String
    let options: [Product]
    let onPick: (Product) -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 16) {
                    ForEach(options) { p in
                        Button { onPick(p) } label: { ClosetTile(product: p) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Pick a \(slot)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
