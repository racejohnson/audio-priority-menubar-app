import Foundation
import Testing
@testable import AudioPriorityCore

@Suite struct DJIReceiverFeedTests {
    /// A status push captured from a DJI Mic Mini receiver (firmware 02.03.11.00)
    /// with its second transmitter linked, on a charger, battery at the top step.
    private static let captured: [UInt8] = bytes("""
        55 56 04 67 5a 02 00 00 00 5b 03 03 46 00 03 00 00 00 00 20 20 01 00 00 00 00 00 00 00 00 00 00
        00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00 3e 00 00 00 02 02 00 00 00 1a 92 27 00 00 00 00
        00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 e1 6e
        """)
    /// A level-meter push from the same receiver: a valid frame with no status in it.
    private static let level: [UInt8] = bytes("55 17 04 38 5a 02 00 00 00 5b 03 03 07 00 05 02 00 00 00 01 01 92 c6")

    private static func bytes(_ hex: String) -> [UInt8] {
        hex.split(whereSeparator: \.isWhitespace).compactMap { UInt8($0, radix: 16) }
    }

    /// The captured frame with some bytes changed and its checksum redone.
    private static func frame(changing changes: [Int: UInt8]) -> [UInt8] {
        var frame = captured
        for (offset, byte) in changes { frame[offset] = byte }
        let crc = DJIReceiverFeed.crc16(frame.dropLast(2))
        frame[frame.count - 2] = UInt8(crc & 0xFF)
        frame[frame.count - 1] = UInt8(crc >> 8)
        return frame
    }

    // In the captured frame the link mask is at byte 44 and the transmitter's status word at 58.
    private static let maskOffset = 44, wordOffset = 58

    @Test func readsACapturedStatus() {
        var feed = DJIReceiverFeed()
        #expect(feed.status == nil)
        let saw1 = feed.consume(Self.captured)
        #expect(saw1)
        #expect(feed.status == TransmitterStatus(isLinked: true, isCharging: true, gauge: 1))
    }

    @Test func aSwitchedOffTransmitterIsNotLinked() {
        var feed = DJIReceiverFeed()
        feed.consume(Self.captured)
        let saw2 = feed.consume(Self.frame(changing: [Self.maskOffset: 0x00]))
        #expect(saw2)
        #expect(feed.status == TransmitterStatus(isLinked: false))
    }

    @Test func readsTheBatteryStepAndChargingFlag() {
        var feed = DJIReceiverFeed()
        // Step 6, not charging: bits 10 to 12 hold 6, bit 9 is clear.
        feed.consume(Self.frame(changing: [Self.wordOffset: 0x92, Self.wordOffset + 1: 0x19]))
        #expect(feed.status == TransmitterStatus(isLinked: true, isCharging: false, gauge: 6))
        #expect(feed.status?.isLow == true)
    }

    @Test func framesMayArriveInPiecesAndAmongOtherTraffic() {
        var feed = DJIReceiverFeed()
        // macOS's accessory link shares the pipe; its bytes include a stray 0x55.
        let noise: [UInt8] = [0xFF, 0x55, 0x02, 0x00, 0xEE, 0x10]
        let all = noise + Self.level + noise + Self.captured
        var sawStatus = false
        for chunk in stride(from: 0, to: all.count, by: 7) {
            if feed.consume(all[chunk..<min(chunk + 7, all.count)]) { sawStatus = true }
        }
        #expect(sawStatus)
        #expect(feed.status?.isLinked == true)
    }

    @Test func aLevelPushAloneGivesNoStatus() {
        var feed = DJIReceiverFeed()
        let saw3 = feed.consume(Self.level)
        #expect(!saw3)
        #expect(feed.status == nil)
    }

    @Test func aDamagedFrameIsDropped() {
        var feed = DJIReceiverFeed()
        var damaged = Self.captured
        damaged[Self.maskOffset] = 0x00   // changed without redoing the checksum
        let saw4 = feed.consume(damaged)
        #expect(!saw4)
        #expect(feed.status == nil)
    }

    @Test func anUnknownLinkMaskIsNotTrusted() {
        var feed = DJIReceiverFeed()
        let saw5 = feed.consume(Self.frame(changing: [Self.maskOffset: 0x7C]))
        #expect(!saw5)
        #expect(feed.status == nil)
    }

    @Test func aFalseStartDoesNotSwallowTheFrameAfterIt() {
        var feed = DJIReceiverFeed()
        // Four bytes that pass as a header and claim more than follows them.
        let claimed = Self.captured.count + 4
        var header: [UInt8] = [0x55, UInt8(claimed & 0xFF), 0x04 | UInt8(claimed >> 8)]
        header.append(DJIReceiverFeed.crc8(header))
        let sawStatus = feed.consume(header + Self.captured)
        #expect(sawStatus)
        #expect(feed.status?.isLinked == true)
    }

    /// The captured frame with a first transmitter's record added after the second's.
    private static func twoTransmitters(mask: UInt8, firstWord: [UInt8]) -> [UInt8] {
        var frame = Array(captured.dropLast(2))
        frame[maskOffset] = mask
        frame += [0x02, 0x01, 0x00, 0x00, 0x00, 0x1a] + firstWord + [UInt8](repeating: 0, count: 22)
        // The frame's own length, and the push's length of what follows it.
        let length = frame.count + 2
        frame[1] = UInt8(length & 0xFF)
        frame[2] = 0x04 | UInt8(length >> 8)
        frame[3] = DJIReceiverFeed.crc8(frame[0..<3])
        frame[12] = UInt8(frame.count - 14)
        let crc = DJIReceiverFeed.crc16(frame)
        return frame + [UInt8(crc & 0xFF), UInt8(crc >> 8)]
    }

    @Test func withTwoTransmittersTheEmptierBatteryShows() {
        var feed = DJIReceiverFeed()
        // The first is at step 5 and not charging; the second, as captured, at step 1.
        let sawStatus = feed.consume(Self.twoTransmitters(mask: 0b11, firstWord: [0x92, 0x15, 0x00, 0x00]))
        #expect(sawStatus)
        #expect(feed.status == TransmitterStatus(isLinked: true, isCharging: false, gauge: 5))
    }

    @Test func aTransmitterThatIsNoLongerLinkedIsIgnored() {
        var feed = DJIReceiverFeed()
        // Only the second is linked; the first's record lingers at step 5.
        feed.consume(Self.twoTransmitters(mask: 0b10, firstWord: [0x92, 0x15, 0x00, 0x00]))
        #expect(feed.status == TransmitterStatus(isLinked: true, isCharging: true, gauge: 1))
    }

    @Test func anUnfamiliarLayoutGivesNoStatus() {
        // The push's own length does not match what follows.
        var feed = DJIReceiverFeed()
        let wrongLength = feed.consume(Self.frame(changing: [12: 0x40]))
        #expect(!wrongLength)
        #expect(feed.status == nil)
        // The receiver's record is not the length this layout has.
        var other = DJIReceiverFeed()
        let wrongRecord = other.consume(Self.frame(changing: [19: 0x1f]))
        #expect(!wrongRecord)
        #expect(other.status == nil)
    }
}
