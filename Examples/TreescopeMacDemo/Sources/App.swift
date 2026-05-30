import SwiftUI
import AppKit
import TreescopeServer

/// A real **macOS** app that embeds the Treescope server and mixes SwiftUI with a
/// genuine AppKit subtree (label, text field, button) bridged in via
/// `NSViewRepresentable`, so the inspector can be exercised against a realistic
/// AppKit + SwiftUI + CALayer tree.
///
/// Run it, then open http://127.0.0.1:50067 in a browser on the same Mac.
@main
struct TreescopeMacDemoApp: App {
    init() {
        // In a real app, guard with `#if DEBUG`.
        Treescope.start()
    }

    var body: some Scene {
        WindowGroup("Treescope macOS") {
            RootView()
        }
        .defaultSize(width: 560, height: 680)
    }
}

private struct RootView: View {
    @State private var toggle = true
    @State private var sliderValue = 0.4
    @State private var name = "Treescope"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "binoculars.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Hello, \(name)!").font(.title).bold()
                    Text("Inspect this window with Treescope").foregroundStyle(.secondary)
                }
            }

            GroupBox("SwiftUI controls") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Name", text: $name)
                    Toggle("SwiftUI toggle", isOn: $toggle)
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $sliderValue)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    if toggle {
                        Label("Enabled", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(8)
            }

            Text("AppKit section").font(.title2).bold()

            // A genuine AppKit subtree embedded via a representable.
            AppKitCard()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Bridges a real `NSView` subtree (label + text field + button + click counter)
/// into SwiftUI so the captured tree contains genuine AppKit views.
private struct AppKitCard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { AppKitCardView() }
    func updateNSView(_ view: NSView, context: Context) {}
}

final class AppKitCardView: NSView {
    private let countLabel = NSTextField(labelWithString: "Clicks: 0")
    private var clicks = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        setAccessibilityIdentifier("appkit.card")

        let title = NSTextField(labelWithString: "AppKit Card")
        title.font = .preferredFont(forTextStyle: .headline)
        title.setAccessibilityIdentifier("appkit.title")

        let field = NSTextField(string: "")
        field.placeholderString = "Type here…"
        field.setAccessibilityIdentifier("appkit.textField")

        countLabel.setAccessibilityIdentifier("appkit.count")

        let button = NSButton(title: "Click me", target: self, action: #selector(click))
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier("appkit.button")

        let stack = NSStackView(views: [title, field, countLabel, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func click() {
        clicks += 1
        countLabel.stringValue = "Clicks: \(clicks)"
    }
}
