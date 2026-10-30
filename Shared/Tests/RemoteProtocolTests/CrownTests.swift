import Testing
@testable import RemoteProtocol

struct CrownTests {
    private let span = 2001 // -1000 through 1000

    @Test func ordinaryTurns() {
        #expect(Crown.isTurningUp(from: 0, to: 1, span: span) == true)
        #expect(Crown.isTurningUp(from: 0, to: -1, span: span) == false)
        #expect(Crown.isTurningUp(from: 40, to: 35, span: span) == false)
        #expect(Crown.isTurningUp(from: 5, to: 5, span: span) == nil)
    }

    @Test func turningUpPastTheTopIsStillUp() {
        #expect(Crown.isTurningUp(from: 1000, to: -1000, span: span) == true)
        #expect(Crown.isTurningUp(from: 1000, to: -999, span: span) == true)
        // The wrap may be counted either as 2000 or 2001 values.
        #expect(Crown.isTurningUp(from: 999, to: -1000, span: span) == true)
    }

    @Test func turningDownPastTheBottomIsStillDown() {
        #expect(Crown.isTurningUp(from: -1000, to: 1000, span: span) == false)
        #expect(Crown.isTurningUp(from: -1000, to: 999, span: span) == false)
    }

    @Test func aBigButHonestTurnIsNotAWrap() {
        #expect(Crown.isTurningUp(from: -400, to: 400, span: span) == true)
        #expect(Crown.isTurningUp(from: 400, to: -400, span: span) == false)
    }
}
