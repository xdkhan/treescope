import SwiftUI
import UIKit
import TreescopeServer

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Treescope.start()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: RootView())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

private struct RootView: View {
    @State private var toggle = true
    @State private var sliderValue = 0.4

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("SwiftUI section")
                        .font(.title)
                        .bold()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Controls")
                            .font(.headline)

                        Toggle("SwiftUI toggle", isOn: $toggle)
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $sliderValue)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        if toggle {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Enabled")
                            }
                            .foregroundColor(.green)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                    Text("UIKit section (touch + keyboard)")
                        .font(.title)
                        .bold()

                    UIKitCard()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(20)
            }
            .navigationBarTitle("Treescope iOS", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct UIKitCard: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitCardController { UIKitCardController() }
    func updateUIViewController(_ controller: UIKitCardController, context: Context) {}
}

final class UIKitCardController: UIViewController {
    private let countLabel = UILabel()
    private var taps = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        view.accessibilityIdentifier = "uikit.card"

        let title = UILabel()
        title.text = "UIKit Card"
        title.font = .preferredFont(forTextStyle: .headline)
        title.accessibilityIdentifier = "uikit.title"

        let field = UITextField()
        field.placeholder = "Type here (keyboard)…"
        field.borderStyle = .roundedRect
        field.accessibilityIdentifier = "uikit.textField"

        countLabel.text = "Taps: 0"
        countLabel.accessibilityIdentifier = "uikit.count"

        let button = UIButton(type: .system)
        button.setTitle("Tap me", for: .normal)
        if #available(iOS 15.0, *) {
            button.configuration = .borderedProminent()
        }
        button.accessibilityIdentifier = "uikit.button"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, field, countLabel, button])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
        ])
    }

    @objc private func tap() {
        taps += 1
        countLabel.text = "Taps: \(taps)"
    }
}
