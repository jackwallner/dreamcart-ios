import SwiftUI

/// Editable shipping address, reachable from the You tab and from checkout.
/// Nothing here ever ships anything real — see ShippingAddress — but the form
/// itself is a straight, real-feeling ecomm shipping form so filling it in is
/// part of the dopamine-shopping fantasy.
struct ShippingAddressView: View {
    @Environment(ShippingAddressStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var draft = ShippingAddress()
    @State private var showClearConfirm = false
    @FocusState private var focused: Field?

    private enum Field { case name, line1, line2, city, state, zip, country }

    private var canSave: Bool { draft.isValid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formCard
                    if !store.address.isEmpty {
                        clearButton
                    }
                    Text("Playful flourish only. DreamCart is a virtual shopping game, so nothing is ever actually shipped here.")
                        .font(.dcCaption)
                        .foregroundStyle(Theme.subtle(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(16)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Shipping address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.address = draft
                        Analytics.track("shipping_address_saved")
                        Haptics.success()
                        dismiss()
                    }
                    .font(.dcLabel)
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack { Spacer(); Button("Done") { focused = nil } }
                }
            }
            .onAppear { draft = store.address }
            .confirmationDialog("Clear your saved shipping address?",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear address", role: .destructive) {
                    draft = ShippingAddress()
                    store.address = draft
                    Haptics.rigid()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("shippingbox.fill", "Where should it \"ship\"?")
            Text("Give your dream orders a place to land. This fictional address is saved on this device for checkout flavor only.")
                .font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
            field("Full name", text: $draft.name, field: .name, content: .name)
            field("Address line 1", text: $draft.line1, field: .line1, content: .streetAddressLine1)
            field("Address line 2 (optional)", text: $draft.line2, field: .line2, content: .streetAddressLine2)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    field("City", text: $draft.city, field: .city, content: .addressCity)
                    field("State", text: $draft.state, field: .state, content: .addressState)
                        .frame(width: 90)
                }
                VStack(spacing: 10) {
                    field("City", text: $draft.city, field: .city, content: .addressCity)
                    field("State", text: $draft.state, field: .state, content: .addressState)
                }
            }
            HStack(spacing: 10) {
                field("ZIP / postal code", text: $draft.zip, field: .zip, content: .postalCode)
                field("Country", text: $draft.country, field: .country, content: .countryName)
            }
        }
        .padding(16)
        .cardStyle(scheme)
    }

    private var clearButton: some View {
        Button {
            showClearConfirm = true
        } label: {
            Text("Clear saved address")
                .font(.dcBody)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .cardStyle(scheme)
    }

    private func field(_ placeholder: String, text: Binding<String>, field: Field,
                       content: UITextContentType) -> some View {
        TextField(placeholder, text: text)
            .font(.dcBody)
            .foregroundStyle(Theme.ink(scheme))
            .textContentType(content)
            .autocorrectionDisabled(field != .name)
            .focused($focused, equals: field)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Theme.bg(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.subtle(scheme).opacity(0.2)))
    }

    private func cardHeader(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.dcIconS).foregroundStyle(Theme.violet)
            Text(title).font(.dcCard).foregroundStyle(Theme.ink(scheme))
        }
    }
}
