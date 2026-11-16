import AudioPriorityCore
import Foundation
import IOKit
import IOUSBHost

/// Listens to the status a DJI Mic Mini receiver broadcasts over USB, so the
/// app knows when the microphone itself is switched off: the receiver stays
/// plugged in, and to CoreAudio nothing has changed.
///
/// It only ever reads. The receiver's other USB channel takes commands,
/// including ones that start a firmware update, and is never opened.
/// macOS's own accessory service reads the same interface; opening it without
/// seizing it lets both carry on.
final class DJIReceiver: @unchecked Sendable {
    private static let vendorID = 0x2CA3, productID = 0x4011
    /// The vendor interface and its bulk-in pipe.
    private static let interfaceNumber = 6, pipeAddress = 0x86
    /// A link that drops for less than this is not reported as the microphone
    /// going off, so a moment out of range does not move a call to another microphone.
    private static let offGrace: TimeInterval = 3
    /// With no status for this long, nothing is known and nothing is claimed.
    private static let staleAfter: TimeInterval = 3

    private let onChange: @MainActor @Sendable (TransmitterStatus?) -> Void
    private let lock = NSLock()
    private var isWanted = false
    private var thread: Thread?

    init(onChange: @escaping @MainActor @Sendable (TransmitterStatus?) -> Void) {
        self.onChange = onChange
    }

    /// Starts or stops listening. Wanted while a receiver is plugged in.
    func setWanted(_ wanted: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isWanted = wanted
        guard wanted, thread == nil else { return }
        let thread = Thread { [self] in run() }
        thread.name = "DJI receiver"
        thread.qualityOfService = .utility
        self.thread = thread
        thread.start()
    }

    /// Whether to keep going; clears the thread when not, under the same lock
    /// `setWanted` starts one under.
    private func shouldContinue() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if !isWanted { thread = nil }
        return isWanted
    }

    private var published: TransmitterStatus??

    private func publish(_ status: TransmitterStatus?) {
        guard published != .some(status) else { return }
        published = .some(status)
        Task { @MainActor [onChange] in onChange(status) }
    }

    private func run() {
        while shouldContinue() {
            listen()
            publish(nil)
            // The receiver was unplugged, the Mac slept, or the pipe failed: try again shortly.
            if shouldContinue() { Thread.sleep(forTimeInterval: 2) }
        }
    }

    /// Reads until the receiver goes away or listening is no longer wanted.
    private func listen() {
        let matching = IOUSBHostInterface.__createMatchingDictionary(
            withVendorID: Self.vendorID as NSNumber, productID: Self.productID as NSNumber, bcdDevice: nil,
            interfaceNumber: Self.interfaceNumber as NSNumber, configurationValue: 1,
            interfaceClass: nil, interfaceSubclass: nil, interfaceProtocol: nil, speed: nil, productIDArray: nil
        ).takeRetainedValue()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        // No options: the interface is shared, not seized.
        guard let interface = try? IOUSBHostInterface(__ioService: service, options: [], queue: nil, interestHandler: nil) else { return }
        defer { interface.destroy() }
        guard let pipe = try? interface.copyPipe(withAddress: Self.pipeAddress) else { return }

        var feed = DJIReceiverFeed()
        var lastStatus = Date()
        var offSince: Date?
        guard let buffer = NSMutableData(length: 1024) else { return }
        while shouldContinue() {
            var count = 0
            do {
                try pipe.__sendIORequest(with: buffer, bytesTransferred: &count, completionTimeout: 1)
            } catch {
                // A quiet second is not a failure; anything else ends this session.
                guard UInt32(truncatingIfNeeded: (error as NSError).code) == 0xE000_02D6 else { return }
            }
            let now = Date()
            if count > 0, feed.consume(Data(referencing: buffer).prefix(count)) {
                lastStatus = now
                if feed.status?.isLinked == false {
                    offSince = offSince ?? now
                    if now.timeIntervalSince(offSince ?? now) >= Self.offGrace { publish(feed.status) }
                } else {
                    offSince = nil
                    publish(feed.status)
                }
            } else if now.timeIntervalSince(lastStatus) > Self.staleAfter {
                publish(nil)
            }
        }
    }
}
