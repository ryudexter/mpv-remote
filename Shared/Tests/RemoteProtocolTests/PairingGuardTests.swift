import Foundation
import Testing
@testable import RemoteProtocol

struct BackoffTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func allowanceIsFree() {
        var backoff = Backoff(allowance: 2, base: 30, cap: 3600)
        backoff.strike(at: start)
        backoff.strike(at: start)
        #expect(!backoff.isBlocked(at: start))
        backoff.strike(at: start)
        #expect(backoff.isBlocked(at: start))
    }

    @Test func blocksDoubleUpToTheCap() {
        var backoff = Backoff(base: 10, cap: 50)
        var now = start
        var waits: [TimeInterval] = []
        for _ in 0..<5 {
            backoff.strike(at: now)
            // Find how long it blocks by probing.
            let wait = (0..<200).first { !backoff.isBlocked(at: now.addingTimeInterval(Double($0))) } ?? 200
            waits.append(TimeInterval(wait))
            now.addTimeInterval(Double(wait))
        }
        #expect(waits == [10, 20, 40, 50, 50])
    }

    @Test func forgetsAfterQuietTime() {
        var backoff = Backoff(base: 10, cap: 600, forgetAfter: 100)
        backoff.strike(at: start)
        backoff.strike(at: start.addingTimeInterval(10))
        #expect(backoff.strikes == 2)
        backoff.strike(at: start.addingTimeInterval(500))
        #expect(backoff.strikes == 1)
        #expect(backoff.isBlocked(at: start.addingTimeInterval(505)))
        #expect(!backoff.isBlocked(at: start.addingTimeInterval(511)))
    }
}

struct PairingGuardTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let guesser = "10.0.0.9"

    @Test func aSourceIsLockedOutAfterThreeWrongCodes() {
        var pairing = PairingGuard()
        for _ in 0..<2 {
            _ = pairing.recordWrongGuess(from: guesser, at: start)
            #expect(pairing.allowsGuess(from: guesser, at: start))
        }
        _ = pairing.recordWrongGuess(from: guesser, at: start)
        #expect(!pairing.allowsGuess(from: guesser, at: start))
        #expect(!pairing.allowsGuess(from: guesser, at: start.addingTimeInterval(29)))
        #expect(pairing.allowsGuess(from: guesser, at: start.addingTimeInterval(31)))
        // Someone else is not affected.
        #expect(pairing.allowsGuess(from: "10.0.0.10", at: start))
    }

    @Test func eachLockoutIsLongerThanTheLast() {
        var pairing = PairingGuard(guessesPerCode: 1000)
        var now = start
        var waits: [Int] = []
        for _ in 0..<5 {
            _ = pairing.recordWrongGuess(from: guesser, at: now)
            _ = pairing.recordWrongGuess(from: guesser, at: now)
            _ = pairing.recordWrongGuess(from: guesser, at: now)
            let wait = (0..<4000).first { pairing.allowsGuess(from: guesser, at: now.addingTimeInterval(Double($0))) } ?? 4000
            waits.append(wait)
            now.addTimeInterval(Double(wait))
        }
        // 3 wrong codes -> 30 s; the next one wrong code after that -> 60 s, 120 s...
        #expect(waits.first == 30)
        #expect(waits == waits.sorted())
        #expect(Set(waits).count > 3)
    }

    @Test func codeChangesAfterFiveWrongCodesInTotalAndGuessingPauses() {
        var pairing = PairingGuard()
        var rotations = 0
        // Five different addresses, so none is locked out by itself.
        for index in 0..<5 {
            if pairing.recordWrongGuess(from: "10.0.0.\(index)", at: start) { rotations += 1 }
        }
        #expect(rotations == 1)
        #expect(!pairing.allowsGuess(from: "10.0.0.50", at: start))
        #expect(!pairing.allowsGuess(from: "10.0.0.50", at: start.addingTimeInterval(14)))
        #expect(pairing.allowsGuess(from: "10.0.0.50", at: start.addingTimeInterval(16)))
    }

    @Test func thePauseGrowsWhenGuessingKeepsUp() {
        var pairing = PairingGuard()
        var now = start
        var waits: [Int] = []
        for round in 0..<4 {
            for index in 0..<5 {
                _ = pairing.recordWrongGuess(from: "10.\(round).0.\(index)", at: now)
            }
            let wait = (0..<2000).first { pairing.allowsGuess(from: "10.99.0.1", at: now.addingTimeInterval(Double($0))) } ?? 2000
            waits.append(wait)
            now.addTimeInterval(Double(wait))
        }
        #expect(waits == [15, 30, 60, 120])
    }

    @Test func guessingAfterTheCodeChangedStartsFromTheNewCode() {
        var pairing = PairingGuard()
        for index in 0..<5 { _ = pairing.recordWrongGuess(from: "10.0.0.\(index)", at: start) }
        let later = start.addingTimeInterval(20)
        // The counter restarted: four more wrong codes don't change it again.
        var rotated = false
        for index in 0..<4 { rotated = rotated || pairing.recordWrongGuess(from: "10.1.0.\(index)", at: later) }
        #expect(!rotated)
    }

    @Test func pairingClearsTheRecord() {
        var pairing = PairingGuard()
        for _ in 0..<3 { _ = pairing.recordWrongGuess(from: guesser, at: start) }
        #expect(!pairing.allowsGuess(from: guesser, at: start))
        pairing.recordPairing(from: guesser)
        #expect(pairing.allowsGuess(from: guesser, at: start))
    }

    @Test func announcementsAreRationedAndGrowingGapsApply() {
        var pairing = PairingGuard()
        var now = start
        // The first two showings go through at once; then the gap grows.
        let first = pairing.allowsAnnouncement(for: "10.0.0.1", at: now)
        let second = pairing.allowsAnnouncement(for: "10.0.0.2", at: now)
        let tooSoon = pairing.allowsAnnouncement(for: "10.0.0.3", at: now.addingTimeInterval(5))
        #expect(first && second && !tooSoon)
        now.addTimeInterval(16)
        let third = pairing.allowsAnnouncement(for: "10.0.0.3", at: now)
        // The next gap is 30 s.
        let beforeThirty = pairing.allowsAnnouncement(for: "10.0.0.4", at: now.addingTimeInterval(29))
        let afterThirty = pairing.allowsAnnouncement(for: "10.0.0.4", at: now.addingTimeInterval(31))
        #expect(third && !beforeThirty && afterThirty)
    }

    @Test func aLockedOutSourceGetsNoAnnouncements() {
        var pairing = PairingGuard()
        for _ in 0..<3 { _ = pairing.recordWrongGuess(from: guesser, at: start) }
        let forGuesser = pairing.allowsAnnouncement(for: guesser, at: start)
        let forOther = pairing.allowsAnnouncement(for: "10.0.0.77", at: start)
        #expect(!forGuesser && forOther)
    }

    @Test func pairingResetsTheAnnouncementGap() {
        var pairing = PairingGuard()
        _ = pairing.allowsAnnouncement(for: nil, at: start)
        _ = pairing.allowsAnnouncement(for: nil, at: start)
        let blocked = pairing.allowsAnnouncement(for: nil, at: start)
        pairing.recordPairing(from: "10.0.0.1")
        let afterPairing = pairing.allowsAnnouncement(for: nil, at: start)
        #expect(!blocked && afterPairing)
    }

    @Test func sourcesAreBoundedInNumber() {
        var pairing = PairingGuard(guessesPerCode: 1_000_000)
        for index in 0..<(PairingGuard.maxSources + 50) {
            _ = pairing.recordWrongGuess(from: "10.0.\(index / 256).\(index % 256)", at: start)
        }
        // Not a crash, and a newcomer can still be judged.
        #expect(pairing.allowsGuess(from: "192.168.1.1", at: start))
    }

    @Test func ipv6IsCutToItsNetwork() {
        let a = [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 1, 1, 2, 3, 4, 5, 6, 7, 8] as [UInt8]
        let b = [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 1, 9, 9, 9, 9, 9, 9, 9, 9] as [UInt8]
        let c = [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 2, 1, 2, 3, 4, 5, 6, 7, 8] as [UInt8]
        #expect(PairingGuard.source(of: a) == PairingGuard.source(of: b))
        #expect(PairingGuard.source(of: a) != PairingGuard.source(of: c))
        #expect(PairingGuard.source(of: [192, 168, 1, 20]) == "192.168.1.20")
        #expect(PairingGuard.source(of: []) == "unknown")
    }
}
