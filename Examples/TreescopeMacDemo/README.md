# TreescopeMacDemo

A real **macOS** app that embeds `TreescopeServer`, used to verify capture on macOS
(AppKit + SwiftUI + CALayer). It mixes a SwiftUI screen with a genuine AppKit subtree
(label, text field, button) bridged in via `NSViewRepresentable`.

The Xcode project is generated with [xcodegen](https://github.com/yonaskolb/XcodeGen) from
`project.yml` (so it isn't committed). It depends on the local SwiftPM package at the repo root.

## Run it

```bash
cd Examples/TreescopeMacDemo
./run.sh                       # generate + build + launch + verify
```

Or step by step:

```bash
xcodegen generate
xcodebuild -project TreescopeMacDemo.xcodeproj -scheme TreescopeMacDemo \
  -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/TreescopeMacDemo.app
```

Then open **http://127.0.0.1:50067** in any browser on the same Mac — the server binds the
Mac's loopback interface, so it's reachable locally with no extra setup.

## Verify headlessly

`verify.mjs` connects over WebSocket, handshakes, fetches the hierarchy, and prints a summary:

```bash
node verify.mjs
# VERIFY: handshake ok — TreescopeMacDemo on macOS 26.3.0 (sim=false)
# VERIFY: captured N nodes — … AppKit, … SwiftUI, … CALayer
# VERIFY SUCCEEDED ✅
```
