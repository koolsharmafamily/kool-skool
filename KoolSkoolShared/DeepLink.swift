import Foundation

/// The URLs widgets and the Live Activity open the app with.
enum DeepLink: Equatable, Sendable, CaseIterable {
    /// Starts a Just Start session straight away — the widget's one job.
    case justStart
    case today
    case session

    static let scheme = "koolskool"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        guard let match = Self.allCases.first(where: { $0.host == url.host()?.lowercased() }) else { return nil }
        self = match
    }

    var host: String {
        switch self {
        case .justStart: "just-start"
        case .today: "today"
        case .session: "session"
        }
    }

    /// Built from a literal, so `URL(string:)` cannot fail here. The fallback is
    /// unreachable and exists only to keep the codebase free of force unwraps.
    var url: URL {
        URL(string: "\(Self.scheme)://\(host)") ?? URL(fileURLWithPath: "/")
    }
}
