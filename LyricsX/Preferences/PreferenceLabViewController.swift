import AppKit
import LyricsXFoundation
import LyricsService

class PreferenceLabViewController: PreferenceViewController {
    @IBOutlet var enableTouchBarLyricsButton: NSButton!

    @IBOutlet var musixmatchTokenField: NSTextField!

    @IBOutlet var useAppleMusicLyricsWindowButton: NSButton!

    @IBOutlet var appleMusicNameRecoveryButton: NSButton!

    @IBOutlet var artworkSimilarityBoostButton: NSButton!

    @IBOutlet weak var appleMusicMediaUserTokenField: NSTextField!
    @IBOutlet weak var appleMusicStorefrontField: NSTextField!
    @IBOutlet weak var appleMusicLanguageField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        enableTouchBarLyricsButton.bind(.value, withDefaultName: .touchBarLyricsEnabled)
        artworkSimilarityBoostButton.bind(.value, withDefaultName: .artworkSimilarityBoostEnabled)

        useAppleMusicLyricsWindowButton.bind(.value, withDefaultName: .useAppleMusicLyricsWindow)
        if #available(macOS 15, *) {
            // Available — leave the checkbox interactive.
        } else {
            useAppleMusicLyricsWindowButton.isEnabled = false
            useAppleMusicLyricsWindowButton.toolTip = NSLocalizedString(
                "Requires macOS 15 or later",
                comment: "Tooltip on the Apple Music-style lyrics window toggle when the OS is too old."
            )
        }

        // Name recovery uses the web session (not MusicKit entitlements), so
        // no MusicAuthorization prompt is needed.
        appleMusicNameRecoveryButton.bind(.value, withDefaultName: .appleMusicNameRecoveryEnabled)
        if #available(macOS 12, *) {
            // Available — leave the checkbox interactive.
        } else {
            appleMusicNameRecoveryButton.isEnabled = false
            appleMusicNameRecoveryButton.toolTip = NSLocalizedString(
                "Requires macOS 12 or later",
                comment: "Tooltip on the Apple Music name recovery toggle when the OS is too old."
            )
        }

        if let token = defaults[.musixmatchToken] {
            musixmatchTokenField.stringValue = token
        } else {
            musixmatchTokenField.stringValue = ""
        }

        if let token = defaults[.appleMusicMediaUserToken] {
            appleMusicMediaUserTokenField.stringValue = token
        }
        if let sf = defaults[.appleMusicStorefront] {
            appleMusicStorefrontField.stringValue = sf
        }
        if let lang = defaults[.appleMusicLanguage] {
            appleMusicLanguageField.stringValue = lang
        }
    }

    // MARK: - Musixmatch token

    @IBAction func musixmatchTokenChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            defaults.remove(.musixmatchToken)
        } else {
            defaults[.musixmatchToken] = value
        }

        // Update lyrics manager when token changes
        Task { await AppController.shared.updateLyricsManager() }
    }

    // MARK: - Apple Music media-user-token

    /// The user pastes their `media-user-token` (obtained from Safari /
    /// Apple Music cookies). Saving it reconfigures the web session so
    /// MusicKit on the background page picks up the injected cookie.
    @IBAction func appleMusicMediaUserTokenChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            defaults.remove(.appleMusicMediaUserToken)
            if #available(macOS 12.0, *) {
                Task { @MainActor in
                    await AppleMusicWebSession.shared.clearToken()
                    await AppController.shared.updateLyricsManager()
                }
            }
        } else {
            defaults[.appleMusicMediaUserToken] = value
            if #available(macOS 12.0, *) {
                Task { @MainActor in
                    await AppleMusicWebSession.shared.configure(mediaUserToken: value)
                    await AppController.shared.updateLyricsManager()
                }
            }
        }
    }

    // MARK: - Apple Music storefront / language

    @IBAction func appleMusicStorefrontChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = value.isEmpty ? nil : value
        defaults[.appleMusicStorefront] = trimmed
        if #available(macOS 12.0, *) {
            AppleMusicWebSession.shared.storefrontOverride = trimmed
        }
    }

    @IBAction func appleMusicLanguageChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = value.isEmpty ? nil : value
        defaults[.appleMusicLanguage] = trimmed
        if #available(macOS 12.0, *) {
            AppleMusicWebSession.shared.languageOverride = trimmed
        }
    }

    @IBAction func customizeAllowsNowPlayingApplicationsAction(_ sender: NSButton) {
        let viewController = NowPlayingApplicationListViewController()
        viewController.preferredContentSize = .init(width: 600, height: 500)
        presentAsSheet(viewController)
    }

    @IBAction func customizeTouchBarAction(_ sender: NSButton) {
        NSApplication.shared.toggleTouchBarCustomizationPalette(sender)
    }
}
