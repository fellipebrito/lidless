import SwiftUI
import ServiceManagement

/// Lidless: the Eye that never sleeps, on an app about lids.
///
/// Menu bar only. `LSUIElement` in Info.plist removes the Dock icon and the menu
/// bar, which is what makes this feel like a utility rather than an application,
/// while leaving it findable in Spotlight because it is still a real .app.
@main
struct LidlessApp: App {
    @State private var hold = Hold()

    init() {
        // Registered on first launch so the icon is simply there tomorrow. The hold
        // itself stays off: an app that silently changes a laptop's power behaviour
        // at login is how someone's battery dies in a bag.
        if SMAppService.mainApp.status == .notRegistered {
            try? SMAppService.mainApp.register()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(hold: hold)
        } label: {
            // A template SF Symbol, so it inverts correctly in light and dark menu
            // bars and under Reduce Transparency without shipping two assets.
            Image(systemName: hold.isHolding ? "eye.fill" : "eye")
                .accessibilityLabel(hold.isHolding ? "Lidless: the Eye is open" : "Lidless: idle")
        }
        .menuBarExtraStyle(.window)
    }
}
