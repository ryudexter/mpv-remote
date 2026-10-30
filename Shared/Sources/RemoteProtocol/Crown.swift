/// Reading the Apple Watch's Digital Crown.
public enum Crown {
    /// Which way the crown turned between two readings: true for up, false for
    /// down, nil if it didn't move.
    ///
    /// A crown set to wrap around jumps from one end of its range to the other
    /// (from 1000 to -1000) when it turns past the end. That is one step in the
    /// direction it was turning, not a huge step the other way, so a change of
    /// more than half of `span` (the number of values it can have) is a wrap.
    public static func isTurningUp(from old: Int, to new: Int, span: Int) -> Bool? {
        let change = new - old
        guard change != 0 else { return nil }
        if abs(change) > span / 2 { return change < 0 }
        return change > 0
    }
}
