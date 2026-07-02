import Foundation

/// Build-time defaults for the sample app. The SDK key is injected via
/// `Secrets.xcconfig` → `HUBBLE_SDK_KEY` → `Info.plist` (`HubbleSDKKey`).
/// `Secrets.xcconfig` is gitignored; copy `Secrets.template.xcconfig` after
/// cloning and fill in your key.
enum DefaultConfig {
    static let sdkKey: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "HubbleSDKKey") as? String,
            !value.isEmpty,
            value != "hsk_REPLACE_ME"
        else {
            fatalError(
                "HubbleSDKKey is missing. Copy Secrets.template.xcconfig to " +
                "Secrets.xcconfig, fill in your SDK key, and rebuild."
            )
        }
        return value
    }()
}
