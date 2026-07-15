import SwiftUI

struct NotificationPrimerView: View {
    @Environment(LocalNotificationCoordinator.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Theme.violet)
            VStack(spacing: 8) {
                Text("A little heads-up?")
                    .font(.dcTitle)
                    .foregroundStyle(Theme.ink(scheme))
                Text("Get one gentle reminder when fresh drops are ready. You can choose the time, and you can change this anytime in Profile.")
                    .font(.dcBody)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                CandyButton(title: isWorking ? "Turning on…" : "Turn on", systemImage: "bell.fill", enabled: !isWorking) {
                    isWorking = true
                    Task {
                        _ = await notifications.requestAuthorizationAndEnable()
                        isWorking = false
                        dismiss()
                    }
                }
                Button("Not now") {
                    notifications.isPrimerShown = true
                    dismiss()
                }
                .font(.dcLabel)
                .foregroundStyle(Theme.subtle(scheme))
            }
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { notifications.isPrimerShown = true }
    }
}
