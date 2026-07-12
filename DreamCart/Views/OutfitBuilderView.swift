import SwiftUI

// The dressing room: pick one owned piece per slot and watch your avatar wear
// the whole fit, rendered as one on-model editorial shot. Looks can be saved.
struct OutfitBuilderView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @AppStorage("avatarLook") private var lookRaw = AvatarLook.aria.rawValue

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

    private var look: AvatarLook { AvatarLook(rawValue: lookRaw) ?? .aria }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if shop.closet.isEmpty {
                    EmptyState(icon: "hanger", title: "Nothing to style yet",
                               message: "Buy a few pieces, then come back to dress up your avatar.")
                        .padding(.top, 40)
                } else {
                    avatarPreview
                    lookPicker
                    slotList
                    saveRow
                    if !shop.outfits.isEmpty { savedLooks }
                }
            }
            .padding(16)
        }
        .background(Theme.bg(scheme))
        .navigationTitle("Dressing room")
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

    // MARK: avatar

    private var avatarPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.candy.opacity(0.12))
            if chosen.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.arms.open")
                        .font(.dcIconXL).foregroundStyle(Theme.violet)
                    Text("Pick pieces below to dress your avatar")
                        .font(.dcBodyText)
                        .foregroundStyle(Theme.subtle(scheme))
                }
            } else {
                CompositeAvatarView(look: look, picks: picks)
                    .padding(10)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(chosen.count) piece\(chosen.count == 1 ? "" : "s")")
                            .font(.dcCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(10)
                    }
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Avatar preview")
    }

    private var lookPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AvatarLook.allCases) { l in
                    FilterChip(label: l.label, selected: look == l) { lookRaw = l.rawValue }
                }
            }
        }
    }

    // MARK: slots

    private var slotList: some View {
        VStack(spacing: 10) {
            ForEach(slots, id: \.key) { slot in
                let available = shop.closet.contains { $0.slot == slot.key }
                HStack(spacing: 12) {
                    Image(systemName: slot.icon)
                        .font(.dcIconM)
                        .foregroundStyle(available ? Theme.violet : Theme.subtle(scheme).opacity(0.4))
                        .frame(width: 26)
                    Text(slot.label)
                        .font(.dcBody)
                        .foregroundStyle(available ? Theme.ink(scheme) : Theme.subtle(scheme).opacity(0.5))
                    Spacer()
                    if let p = picks[slot.key] {
                        Text(p.name).font(.dcItem)
                            .foregroundStyle(Theme.subtle(scheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                        RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                            .frame(width: 34, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        Button {
                            Haptics.tap(); picks[slot.key] = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.dcIconM)
                                .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(p.name) from \(slot.label)")
                    } else if available {
                        Text("Choose").font(.dcLabel)
                            .foregroundStyle(Theme.violet)
                    } else {
                        Text("None owned").font(.dcSub)
                            .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14).padding(.vertical, 11)
                .cardStyle(scheme)
                .onTapGesture {
                    if available { Haptics.tap(); pickingSlot = SlotID(id: slot.key) }
                }
                .accessibilityAddTraits(available ? .isButton : [])
                .accessibilityHint(available ? "Opens owned \(slot.label.lowercased())" : "No owned pieces")
            }
        }
    }

    private var saveRow: some View {
        VStack(spacing: 10) {
            TextField("Name this look", text: $name)
                .font(.dcBody)
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
                        Text(outfit.name).font(.dcItem)
                            .foregroundStyle(Theme.ink(scheme))
                        Spacer()
                        Button {
                            let items = (outfit.outfitItems ?? []).compactMap { $0.products }
                            picks = Dictionary(items.map { ($0.slot, $0) }, uniquingKeysWith: { a, _ in a })
                            Haptics.soft()
                        } label: {
                            Text("Try on").font(.dcLabel)
                                .foregroundStyle(Theme.violet)
                        }
                        Button {
                            Task { await shop.deleteOutfit(outfit.id) }
                        } label: {
                            Image(systemName: "trash").font(.dcIconS).foregroundStyle(Theme.subtle(scheme))
                        }
                        .padding(.leading, 8)
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
