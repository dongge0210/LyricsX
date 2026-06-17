import AppKit
import LyricsXFoundation
import LyricsService

class PreferenceLabViewController: PreferenceViewController {
    @IBOutlet var enableTouchBarLyricsButton: NSButton!

    @IBOutlet var musixmatchTokenField: NSTextField!

    @IBOutlet var useAppleMusicLyricsWindowButton: NSButton!

    @IBOutlet var appleMusicNameRecoveryButton: NSButton!

    @IBOutlet var artworkSimilarityBoostButton: NSButton!

    /// Created programmatically — not wired from the storyboard.
    private var appleMusicMediaUserTokenField: NSTextField!
    private var appleMusicStorefrontField: NSTextField!
    private var appleMusicLanguageField: NSTextField!

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

        setupAppleMusicTokenField()
        setupAppleMusicStorefrontField()
        setupAppleMusicLanguageField()
    }

    // MARK: - Apple Music media-user-token (programmatic)

    private func setupAppleMusicTokenField() {
        // Prevent duplicate rows when view is reloaded.
        guard appleMusicMediaUserTokenField == nil else { return }

        let gridHint = NSLocalizedString(
            "Apple Music Token (media-user-token):",
            comment: "Label for the Apple Music media-user-token field in Lab preferences."
        )

        // Find the NSGridView in the view hierarchy.
        guard let grid = view.subviews.lazy.compactMap({ $0 as? NSGridView }).first else {
            return
        }

        // Label row (matches grid's trailing-aligned column 1 style)
        let label = NSTextField(labelWithString: gridHint)
        label.alignment = .right
        let labelRowIndex = grid.numberOfRows
        grid.addRow(with: [label, NSView()])
        let labelRow = grid.row(at: labelRowIndex)
        labelRow.yPlacement = .center
        labelRow.height = 22

        // Token field row: single cell spanning both columns
        let field = NSTextField()
        field.placeholderString = NSLocalizedString(
            "Paste your media-user-token",
            comment: "Placeholder for Apple Music token field."
        )
        field.bezelStyle = .roundedBezel
        field.target = self
        field.action = #selector(appleMusicMediaUserTokenChanged(_:))

        if let token = defaults[.appleMusicMediaUserToken] {
            field.stringValue = token
        }

        let fieldRowIndex = grid.numberOfRows
        grid.addRow(with: [field, NSView()])
        grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2),
                        verticalRange: NSRange(location: fieldRowIndex, length: 1))
        let fieldRow = grid.row(at: fieldRowIndex)
        fieldRow.yPlacement = .center
        fieldRow.height = 24
        appleMusicMediaUserTokenField = field
    }

    private func setupAppleMusicStorefrontField() {
        guard appleMusicStorefrontField == nil,
              let grid = view.subviews.lazy.compactMap({ $0 as? NSGridView }).first else { return }

        let label = NSTextField(labelWithString: NSLocalizedString(
            "Storefront:",
            comment: "Label for Apple Music storefront field."
        ))
        label.alignment = .right
        let labelRowIndex = grid.numberOfRows
        grid.addRow(with: [label, NSView()])
        grid.row(at: labelRowIndex).yPlacement = .center
        grid.row(at: labelRowIndex).height = 22

        let field = NSTextField()
        field.placeholderString = NSLocalizedString(
            "2-letter code (cn, us, jp…), auto if empty",
            comment: "Placeholder for storefront field."
        )
        field.bezelStyle = .roundedBezel
        field.target = self
        field.action = #selector(appleMusicStorefrontChanged(_:))
        if let sf = defaults[.appleMusicStorefront], !sf.isEmpty {
            field.stringValue = sf
        }

        let fieldRowIndex = grid.numberOfRows
        grid.addRow(with: [field, NSView()])
        grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2),
                        verticalRange: NSRange(location: fieldRowIndex, length: 1))
        grid.row(at: fieldRowIndex).yPlacement = .center
        grid.row(at: fieldRowIndex).height = 24
        appleMusicStorefrontField = field
    }

    private func setupAppleMusicLanguageField() {
        guard appleMusicLanguageField == nil,
              let grid = view.subviews.lazy.compactMap({ $0 as? NSGridView }).first else { return }

        let label = NSTextField(labelWithString: NSLocalizedString(
            "Language:",
            comment: "Label for Apple Music language field."
        ))
        label.alignment = .right
        let labelRowIndex = grid.numberOfRows
        grid.addRow(with: [label, NSView()])
        grid.row(at: labelRowIndex).yPlacement = .center
        grid.row(at: labelRowIndex).height = 22

        let field = NSTextField()
        field.placeholderString = NSLocalizedString(
            "zh-Hans, zh-hans-cn…, auto if empty",
            comment: "Placeholder for language field."
        )
        field.bezelStyle = .roundedBezel
        field.target = self
        field.action = #selector(appleMusicLanguageChanged(_:))
        if let lang = defaults[.appleMusicLanguage], !lang.isEmpty {
            field.stringValue = lang
        }

        let fieldRowIndex = grid.numberOfRows
        grid.addRow(with: [field, NSView()])
        grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2),
                        verticalRange: NSRange(location: fieldRowIndex, length: 1))
        grid.row(at: fieldRowIndex).yPlacement = .center
        grid.row(at: fieldRowIndex).height = 24
        appleMusicLanguageField = field
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
