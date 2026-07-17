import SwiftUI
import UIKit

// Renders the dressing-room avatar as a server-side editorial shot when one is
// available, with an on-device paper-doll composite that remains usable offline.
struct CompositeAvatarView: View {
    let look: AvatarLook
    let picks: [String: Product]
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cutouts: [String: UIImage] = [:]
    @State private var failedCutouts: Set<String> = []
    @State private var renderState: RenderState = .idle
    @State private var renderAttempt = 0
    @State private var requestedRenderKey: String?

    private enum RenderState: Equatable {
        case idle
        case loading
        case ready(String)
        case failed(String)
    }

    var body: some View {
        GeometryReader { geo in
            editorialCanvas(in: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: pickKey) {
            requestedRenderKey = nil
            renderState = .idle
            await loadCutouts(for: pickKey)
        }
        .task(id: renderTaskID) {
            guard requestedRenderKey == renderKey else { return }
            await loadEditorial(for: renderKey)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(look.label) outfit preview")
        .accessibilityValue(renderAccessibilityValue)
    }

    private var chosenItems: [Product] { Array(picks.values) }
    private var renderKey: String { Avatar.renderKey(look: look, items: chosenItems) }
    private var renderTaskID: String { "\(renderKey)#\(renderAttempt)" }
    private var pickKey: [String: String] { picks.mapValues(\.id) }

    private var renderAccessibilityValue: String {
        switch renderState {
        case .idle: return "Composite preview"
        case .loading: return "Rendering editorial preview"
        case .ready: return "Editorial preview ready"
        case .failed: return "Editorial preview unavailable, composite preview shown"
        }
    }

    // Slots that actually have a piece, ordered back-to-front.
    private var placedSlots: [(slot: String, placement: SlotPlacement)] {
        SlotPlacement.bySlot
            .filter { picks[$0.key] != nil }
            .map { (slot: $0.key, placement: $0.value) }
            .sorted { $0.placement.z < $1.placement.z }
    }

    @ViewBuilder
    private func editorialCanvas(in size: CGSize) -> some View {
        ZStack {
            compositeCanvas(in: size)
            if renderState == .idle, !chosenItems.isEmpty {
                VStack {
                    Spacer()
                    Button {
                        requestedRenderKey = renderKey
                        renderAttempt += 1
                    } label: {
                        Label("Render editorial look", systemImage: "sparkles.rectangle.stack")
                            .font(.dcButton)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Theme.candy, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("renderEditorialLookButton")
                    .padding(16)
                }
            }
            switch renderState {
            case .ready(let url):
                // The render-avatar bucket URL is itself the deterministic
                // cache key (hash of look + sorted item ids), so this reuses
                // the app's normal image pipeline — memory/disk cache plus
                // the shared ImageFetchGate and its own 429 backoff — instead
                // of a bare AsyncImage that would refetch and re-decode this
                // hero shot every time the dressing room reappears.
                RemoteImage(url: url, maxPixelSize: 1400)
                    .transition(.opacity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            case .loading:
                renderStatus("Rendering editorial look…", progress: true)
            case .failed(let message):
                renderStatus(message, retry: true)
            case .idle:
                EmptyView()
            }
        }
    }

    private func compositeCanvas(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.candy.opacity(0.07))
            bodyBase(size)
            ForEach(placedSlots, id: \.slot) { entry in
                if let product = picks[entry.slot] {
                    piece(product, entry.placement, in: size)
                        .zIndex(entry.placement.z)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func renderStatus(_ message: String, progress: Bool = false, retry: Bool = false) -> some View {
        VStack(spacing: 8) {
            if progress {
                ProgressView().tint(Theme.violet)
            } else {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.dcIconL)
                    .foregroundStyle(Theme.violet)
            }
            Text(message)
                .font(.dcLabel)
                .foregroundStyle(Theme.ink(scheme))
                .multilineTextAlignment(.center)
            if retry {
                Button("Try again") {
                    requestedRenderKey = renderKey
                    renderAttempt += 1
                }
                    .font(.dcLabel)
                    .foregroundStyle(Theme.violet)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.violet)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(16)
    }

    @ViewBuilder
    private func piece(_ product: Product, _ p: SlotPlacement, in size: CGSize) -> some View {
        Group {
            if let cut = cutouts[product.id] {
                Image(uiImage: cut).resizable().scaledToFit()
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if failedCutouts.contains(product.id) {
                ZStack {
                    RemoteImage(url: product.imageUrl, rarity: product.rarityKind)
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.dcIconM)
                        Text("Using product image")
                            .font(.dcCaption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Couldn’t prepare \(product.name). Showing product image instead.")
            } else {
                ProgressView()
                    .tint(Theme.violet)
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
                    .accessibilityLabel("Preparing \(product.name)")
            }
        }
        .frame(width: size.width * p.w, height: size.height * p.h)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .position(x: size.width * p.cx, y: size.height * p.cy)
    }

    private func bodyBase(_ size: CGSize) -> some View {
        Image(systemName: "figure.stand")
            .resizable().scaledToFit()
            .frame(height: size.height * 0.94)
            .foregroundStyle(look.skinTint.opacity(scheme == .dark ? 0.5 : 0.32))
            .position(x: size.width * 0.5, y: size.height * 0.52)
    }

    private func loadEditorial(for key: String) async {
        guard !chosenItems.isEmpty else {
            guard key == renderKey else { return }
            renderState = .idle
            return
        }
        guard key == renderKey else { return }
        renderState = .loading
        do {
            let url = try await Avatar.render(look: look, items: chosenItems)
            guard !Task.isCancelled, key == renderKey else { return }
            renderState = .ready(url)
        } catch {
            guard !Task.isCancelled, key == renderKey else { return }
            renderState = .failed(error.localizedDescription)
        }
    }

    private func loadCutouts(for key: [String: String]) async {
        for product in chosenItems where cutouts[product.id] == nil {
            guard !Task.isCancelled, key == pickKey else { return }
            if let img = await AvatarCutoutCache.shared.cutout(for: product) {
                guard !Task.isCancelled, key == pickKey else { return }
                if reduceMotion {
                    cutouts[product.id] = img
                } else {
                    withAnimation(.easeOut(duration: 0.25)) { cutouts[product.id] = img }
                }
            } else {
                guard !Task.isCancelled, key == pickKey else { return }
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
