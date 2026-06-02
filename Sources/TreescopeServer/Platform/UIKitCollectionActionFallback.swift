import TreescopeProtocol

#if !canImport(UIKit)
extension CaptureEngine {
    func performUIKitCollectionAction(_ action: UIKitCollectionAction) -> UIKitCollectionActionResult {
        switch action {
        case .query(let identifier), .scroll(let identifier, _, _, _):
            return UIKitCollectionActionResult(status: "unsupportedPlatform",
                                               identifier: identifier,
                                               message: "UIKit collection actions are unavailable on this platform")
        }
    }
}
#endif
