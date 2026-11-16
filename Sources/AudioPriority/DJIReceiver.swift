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
    /// Guards everything below it.
    private let lock = NSLock()
    private var isWanted = false
    private var thread: Thread?
    /// The last status handed on. The outer optional is "nothing handed on yet".
    private var published: TransmitterStatus??

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

    /// Whether the calling thread is still the listener and still wanted. When
    /// it is no longer wanted it steps down here, under the same lock a new
    /// one is started under, so there is never more than one.
    private func shouldContinue() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard thread === Thread.current else { return false }
        if !isWanted {
            thread = nil
            // The next receiver to be plugged in starts from nothing known.
            published = nil
        }
        return isWanted
    }

    private func publish(_ status: TransmitterStatus?) {
        lock.lock()
        let isNews = thread === Thread.current && published != .some(status)
        if isNews { published = .some(status) }
        lock.unlock()
        guard isNews else { return }
        Task { @MainActor [onChange] in onChange(status) }
    }

    private var lastPublishedIsOff: Bool {
        lock.lock()
        defer { lock.unlock() }
        if case .some(.some(let status)) = published { return !status.isLinked }
        return false
    }

    private func run() {
        var isFirstSession = true
        var silentSessions = 0
        while shouldContinue() {
            let heardStatus = listen(isFirstSession: isFirstSession)
            isFirstSession = false
            // A session ends when the Mac sleeps or the pipe hiccups, and the
            // next one usually picks straight up. Only after several with
            // nothing heard is the microphone's state unknown.
            silentSessions = heardStatus ? 0 : silentSessions + 1
            if silentSessions >= 3 { publish(nil) }
            if shouldContinue() { Thread.sleep(forTimeInterval: 2) }
        }
    }

    /// Reads until the receiver goes away or listening is no longer wanted.
    /// True if the receiver said anything about its microphone.
    private func listen(isFirstSession: Bool) -> Bool {
        let matching = IOUSBHostInterface.__createMatchingDictionary(
            withVendorID: Self.vendorID as NSNumber, productID: Self.productID as NSNumber, bcdDevice: nil,
            interfaceNumber: Self.interfaceNumber as NSNumber, configurationValue: 1,
            interfaceClass: nil, interfaceSubclass: nil, interfaceProtocol: nil, speed: nil, productIDArray: nil
        ).takeRetainedValue()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        // No options: the interface is opened without seizing it from macOS's accessory service.
        guard let interface = try? IOUSBHostInterface(__ioService: service, options: [], queue: nil, interestHandler: nil) else { return false }
        defer { interface.destroy() }
        guard let pipe = try? interface.copyPipe(withAddress: Self.pipeAddress),
              let buffer = NSMutableData(length: 1024) else { return false }

        var feed = DJIReceiverFeed()
        var heardStatus = false
        var lastStatus = Date()
        // The grace is for a link that drops. A microphone that is already off
        // when the app starts, or was off before this session, is reported at once.
        var offSince: Date? = isFirstSession || lastPublishedIsOff ? .distantPast : nil
        while shouldContinue() {
            var count = 0
            do {
                try pipe.__sendIORequest(with: buffer, bytesTransferred: &count, completionTimeout: 1)
            } catch {
                // A quiet second is not a failure; anything else ends this session.
                guard UInt32(truncatingIfNeeded: (error as NSError).code) == 0xE000_02D6 else { return heardStatus }
            }
            let now = Date()
            if count > 0, feed.consume(Data(referencing: buffer).prefix(count)) {
                heardStatus = true
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
        return heardStatus
    }
}
