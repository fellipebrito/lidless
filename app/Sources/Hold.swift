import Foundation
import IOKit
import IOKit.pwr_mgt
import AppKit

/// The hold itself, and the two things that must end it.
///
/// The shell version of this shelled out to `caffeinate` and watched `ioreg` in a
/// loop. A real app has no business spawning processes for either: the hold is a
/// power assertion, and the lid is a property on IOPMrootDomain.
///
/// Two conditions release it, and the second one is the subtle one:
///
///  1. The lid closes. Polled, because closing the lid with an external display
///     attached does not put the machine to sleep, so nothing would notify us.
///  2. The machine slept. Event-driven via NSWorkspace, which is strictly better
///     than the shell version's trick of inferring sleep from a poll gap.
@MainActor
@Observable
final class Hold {
    private(set) var isHolding = false
    private(set) var since: Date?
    /// Why the hold ended, if it ended on its own rather than by a click.
    private(set) var lastRelease: String?

    private var displayAssertion: IOPMAssertionID = 0
    private var idleAssertion: IOPMAssertionID = 0
    private var lidTimer: Timer?

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.release(because: "the Mac slept") }
        }
        // The Eye opens on every launch, including the silent one at login. The
        // user can still close it with one click from the menu at any time; this
        // just changes what "one click" is for, from opening to closing.
        start()
    }

    func start() {
        guard !isHolding else { return }
        // Refuse to begin behind a closed lid: the whole point is that this never
        // holds a shut laptop awake.
        guard !Self.lidIsClosed else {
            lastRelease = "the lid is closed"
            return
        }
        let reason = "Lidless is holding this Mac awake" as CFString
        IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    reason, &displayAssertion)
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    reason, &idleAssertion)
        isHolding = true
        since = Date()
        lastRelease = nil

        lidTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Self.lidIsClosed else { return }
                self.release(because: "the lid closed")
            }
        }
    }

    func stop() { release(because: nil) }

    private func release(because reason: String?) {
        guard isHolding else { return }
        lidTimer?.invalidate(); lidTimer = nil
        if displayAssertion != 0 { IOPMAssertionRelease(displayAssertion); displayAssertion = 0 }
        if idleAssertion != 0 { IOPMAssertionRelease(idleAssertion); idleAssertion = 0 }
        isHolding = false
        since = nil
        lastRelease = reason
    }

    /// False on a desktop, which has no clamshell at all. That is correct: there is
    /// no lid to close, so only the sleep notification can end the hold there.
    static var lidIsClosed: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString,
                                                        kCFAllocatorDefault, 0)?
            .takeRetainedValue() else { return false }
        return (raw as? Bool) ?? false
    }

    /// True only on hardware that reports a clamshell, so the UI can avoid promising
    /// lid behaviour on a Mac mini.
    static var hasLid: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString,
                                               kCFAllocatorDefault, 0) != nil
    }
}
