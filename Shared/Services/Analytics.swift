import Foundation

// Lightweight first-party product analytics. `Analytics.track(...)` is a
// fire-and-forget one-liner: it never awaits, never throws to the caller, and
// never blocks the UI. Events are buffered in memory and flushed to Supabase
// in batches (every ~20 events, every ~30s, or when the app backgrounds), and
// silently dropped on failure — this is best-effort telemetry, not a
// delivery-guaranteed pipeline, so a flaky network never surfaces as a user-
// visible error.
//
// First-party only: no IDFA, no cross-app/cross-site identifiers, no ATT
// prompt. Events carry a per-launch session id and the Supabase auth user id
// (nil pre-sign-in). See docs/analytics-privacy.md for the ASC privacy
// questionnaire mapping.
actor Analytics {
    static let shared = Analytics()

    private var buffer: [Event] = []
    private let sessionId = UUID().uuidString
    private let flushThreshold = 20
    private let flushIntervalNanos: UInt64 = 30_000_000_000 // 30s

    private struct Event: Encodable, Sendable {
        let userId: String?
        let sessionId: String
        let name: String
        let props: [String: AnalyticsValue]
        let clientTimestamp: Date
        let appVersion: String
        let locale: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case sessionId = "session_id"
            case name
            case props
            case clientTimestamp = "client_timestamp"
            case appVersion = "app_version"
            case locale
        }
    }

    private init() {
        Task { await runFlushTimer() }
    }

    // MARK: - Public API

    /// Record an event. Safe to call from any actor/thread — hops onto the
    /// analytics actor and returns immediately without awaiting anything.
    nonisolated static func track(_ name: String, _ props: AnalyticsProps = [:]) {
        Task { await shared.enqueue(name: name, props: props) }
    }

    /// Best-effort synchronous-ish drain, called when the app is about to
    /// background so buffered events aren't lost to process suspension.
    static func flushNow() async {
        await shared.flush()
    }

    // MARK: - Internals

    private func enqueue(name: String, props: AnalyticsProps) async {
        let userId = await SupabaseClient.shared.currentUserId
        buffer.append(Event(userId: userId, sessionId: sessionId, name: name,
                            props: props.mapValues { $0.analyticsValue },
                            clientTimestamp: Date(), appVersion: Self.appVersion,
                            locale: Locale.current.identifier))
        if buffer.count >= flushThreshold {
            await flush()
        }
    }

    private func runFlushTimer() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: flushIntervalNanos)
            await flush()
        }
    }

    private func flush() async {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer.removeAll()
        // Drop silently on failure: telemetry must never retry-storm or
        // compete with real app traffic, and never surfaces to the user.
        try? await SupabaseClient.shared.insertBestEffort("analytics_events", rows: batch)
    }

    private static let appVersion: String = {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }()
}

/// The type callers actually write at the call site: `["product_id": id,
/// "price": product.price]`. String/Int/Double/Bool all conform below, so a
/// plain variable or literal of any of those types drops straight into the
/// dictionary literal — no boxing syntax needed at call sites.
typealias AnalyticsProps = [String: any AnalyticsPropertyConvertible]

protocol AnalyticsPropertyConvertible: Sendable {
    var analyticsValue: AnalyticsValue { get }
}
extension String: AnalyticsPropertyConvertible { var analyticsValue: AnalyticsValue { .string(self) } }
extension Int: AnalyticsPropertyConvertible { var analyticsValue: AnalyticsValue { .int(self) } }
extension Double: AnalyticsPropertyConvertible { var analyticsValue: AnalyticsValue { .double(self) } }
extension Bool: AnalyticsPropertyConvertible { var analyticsValue: AnalyticsValue { .bool(self) } }

/// The wire type actually sent to Supabase's jsonb `props` column.
enum AnalyticsValue: Encodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}
