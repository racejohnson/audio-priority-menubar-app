import Foundation

/// Reads the status a DJI Mic receiver broadcasts over USB, several times a
/// second, without being asked: which transmitters are linked, and each one's
/// battery step and charging flag. Nothing is ever sent to the receiver.
///
/// The format is DJI's DUML framing carrying the receiver's status push
/// (command set 0x5B, command 0x03). It was worked out by others and is
/// described in the protocol notes of lavdeck (piedol), DJI-Mic-Control
/// (ShadowBitBasher) and HaloBattery (HeyOkay); the layout read here was
/// checked against a DJI Mic Mini receiver on firmware 02.03.11.00.
///
/// Anything that does not check out (a bad checksum, an unexpected length,
/// a link mask with unknown bits) is dropped, so an unfamiliar firmware
/// yields no status at all and the microphone is treated as present.
public struct DJIReceiverFeed: Sendable {
    private var stream: [UInt8] = []
    private var linked: UInt8?
    /// The status word of each transmitter, by its index (1 or 2).
    private var words: [Int: UInt32] = [:]

    public init() {}

    /// The transmitters' state as last reported, or nil before the first status.
    /// With two linked, the battery shown is the emptier one's.
    public var status: TransmitterStatus? {
        guard let linked else { return nil }
        guard linked != 0 else { return TransmitterStatus(isLinked: false) }
        let live = words.filter { linked & (1 << UInt8($0.key - 1)) != 0 }.values
        guard let word = live.max(by: { Self.gauge($0) < Self.gauge($1) }) else { return TransmitterStatus(isLinked: true) }
        let gauge = Self.gauge(word)
        return TransmitterStatus(isLinked: true, isCharging: word & (1 << 9) != 0, gauge: (1...7).contains(gauge) ? gauge : nil)
    }

    private static func gauge(_ word: UInt32) -> Int { Int((word >> 10) & 7) }

    /// Takes the next bytes from the receiver. True when they held a status.
    @discardableResult
    public mutating func consume(_ bytes: some Sequence<UInt8>) -> Bool {
        stream.append(contentsOf: bytes)
        var sawStatus = false
        while let start = stream.firstIndex(of: 0x55) {
            // Other traffic shares the pipe (macOS's accessory link); skip to a frame start.
            stream.removeFirst(start)
            guard stream.count >= 4 else { break }
            let length = Int(stream[1]) | Int(stream[2] & 0x03) << 8
            // Byte 2's upper six bits are the protocol version, 1; byte 3 checks the first three.
            guard stream[2] >> 2 == 1, length >= 13, Self.crc8(stream[0..<3]) == stream[3] else {
                stream.removeFirst()
                continue
            }
            guard stream.count >= length else { break }
            let frame = Array(stream[0..<length])
            stream.removeFirst(length)
            let stored = UInt16(frame[length - 2]) | UInt16(frame[length - 1]) << 8
            guard Self.crc16(frame[0..<(length - 2)]) == stored else { continue }
            // Command set 0x5B, command 0x03: the status push.
            guard frame[9] == 0x5B, frame[10] == 0x03 else { continue }
            if read(status: frame[11..<(length - 2)]) { sawStatus = true }
        }
        // A frame is at most 1023 bytes; more than that without one is not this protocol.
        if stream.count > 4096 { stream.removeAll() }
        return sawStatus
    }

    /// The push is `03`, a two-byte length, then records of
    /// type (1), index (4, little-endian), length (1), value.
    private mutating func read(status payload: ArraySlice<UInt8>) -> Bool {
        let bytes = Array(payload)
        guard bytes.count >= 3, bytes[0] == 0x03 else { return false }
        var sawReceiver = false
        var offset = 3
        while offset + 6 <= bytes.count {
            let type = bytes[offset], index = Int(bytes[offset + 1]), length = Int(bytes[offset + 5])
            let end = offset + 6 + length
            guard end <= bytes.count else { break }
            let value = bytes[(offset + 6)..<end]
            switch type {
            case 0x03 where index == 0 && length >= 25:
                // The receiver's own record: byte 24 has one bit per linked transmitter.
                let mask = value[value.startIndex + 24]
                guard mask <= 0b11 else { return false }
                linked = mask
                sawReceiver = true
            case 0x02 where (1...2).contains(index) && length >= 4:
                let start = value.startIndex
                words[index] = UInt32(value[start]) | UInt32(value[start + 1]) << 8
                    | UInt32(value[start + 2]) << 16 | UInt32(value[start + 3]) << 24
            default:
                break
            }
            offset = end
        }
        return sawReceiver
    }

    // MARK: Checksums

    /// CRC-8, reflected polynomial 0x8C, starting from 0x77.
    static func crc8(_ bytes: some Sequence<UInt8>) -> UInt8 {
        var crc: UInt8 = 0x77
        for byte in bytes {
            crc ^= byte
            for _ in 0..<8 { crc = crc & 1 != 0 ? (crc >> 1) ^ 0x8C : crc >> 1 }
        }
        return crc
    }

    /// CRC-16, reflected polynomial 0x8408, starting from 0x3692.
    static func crc16(_ bytes: some Sequence<UInt8>) -> UInt16 {
        var crc: UInt16 = 0x3692
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 { crc = crc & 1 != 0 ? (crc >> 1) ^ 0x8408 : crc >> 1 }
        }
        return crc
    }
}
