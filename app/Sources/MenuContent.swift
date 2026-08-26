import SwiftUI

/// The dropdown. Status, one action, and the byline.
struct MenuContent: View {
    @Bindable var hold: Hold
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Circle()
                    .fill(hold.isHolding ? Color.orange : Color.secondary.opacity(0.45))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hold.isHolding ? "The Eye is open" : "The Eye is closed")
                        .font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 12)

            Divider()

            Button(hold.isHolding ? "Close the Eye" : "Open the Eye") {
                hold.isHolding ? hold.stop() : hold.start()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())

            Button("Quit Lidless") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 9)
                .contentShape(Rectangle())

            Divider()

            Link("Built by Fellipe Brito", destination: URL(string: "https://fellipebrito.com")!)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(width: 236)
        .onReceive(tick) { now = $0 }
    }

    /// The one line that has to earn its place: what is true right now, and what
    /// will end it.
    private var detail: String {
        if hold.isHolding {
            let elapsed = Int(now.timeIntervalSince(hold.since ?? now))
            let h = elapsed / 3600, m = (elapsed % 3600) / 60
            let ago = h > 0 ? "\(h)h \(m)m" : "\(m)m"
            return Hold.hasLid
                ? "Awake for \(ago). Closes with the lid."
                : "Awake for \(ago). Closes when the Mac sleeps."
        }
        if let why = hold.lastRelease { return "Closed because \(why)." }
        return Hold.hasLid ? "This Mac can sleep normally." : "This Mac can sleep normally."
    }
}
