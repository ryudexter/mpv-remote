import Foundation

/// A wait that grows. The first `allowance` strikes cost nothing; each one
/// after that blocks for twice as long as the one before, from `base` up to
/// `cap`. Strikes are forgotten once `forgetAfter` passes without a new one.
public struct Backoff: Sendable {
    public let allowance: Int
    public let base: TimeInterval
    public let cap: TimeInterval
    public let forgetAfter: TimeInterval
    public private(set) var strikes = 0
    private var blockedUntil = Date.distantPast
    private var lastStrike = Date.distantPast

    public init(allowance: Int = 0, base: TimeInterval, cap: TimeInterval, forgetAfter: TimeInterval = 3600) {
        self.allowance = allowance
        self.base = base
        self.cap = cap
        self.forgetAfter = forgetAfter
    }

    public func isBlocked(at now: Date) -> Bool {
        now < blockedUntil
    }

    /// Whether this has gone unused long enough to be thrown away.
    public func isForgotten(at now: Date) -> Bool {
        now.timeIntervalSince(lastStrike) > forgetAfter && !isBlocked(at: now)
    }

    public mutating func strike(at now: Date) {
        if isForgotten(at: now) { strikes = 0 }
        strikes += 1
        lastStrike = now
        guard strikes > allowance else { return }
        let doublings = Double(min(strikes - allowance - 1, 30))
        blockedUntil = now.addingTimeInterval(min(cap, base * pow(2, doublings)))
    }
}
