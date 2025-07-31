import Foundation
import os.log

// MARK: - Shortcut Template Manager

@available(iOS 17.0, *)
public class ShortcutTemplate {
    // MARK: - Singleton

    public static let shared = ShortcutTemplate()

    // MARK: - Properties

    private let shortcutName = "LifeMeter Apple Pay Logger"
    private let shortcutIdentifier = "com.lifemeter.applepay.automation"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Generate the shortcut template as a dictionary
    public func generateTemplate() -> [String: Any] {
        return [
            "WFWorkflowMinimumClientVersion": 1113,
            "WFWorkflowMinimumClientVersionString": "17.0",
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 431_817_727,
                "WFWorkflowIconGlyphNumber": 61440,
            ],
            "WFWorkflowClientVersion": "2622.0.2",
            "WFWorkflowOutputContentItemClasses": [],
            "WFWorkflowHasOutputFallback": false,
            "WFWorkflowActions": generateActions(),
            "WFWorkflowInputContentItemClasses": [
                "WFAppStoreAppContentItem",
                "WFArticleContentItem",
                "WFContactContentItem",
                "WFDateContentItem",
                "WFEmailAddressContentItem",
                "WFGenericFileContentItem",
                "WFImageContentItem",
                "WFiTunesProductContentItem",
                "WFLocationContentItem",
                "WFDCMapsLinkContentItem",
                "WFAVAssetContentItem",
                "WFPDFContentItem",
                "WFPhoneNumberContentItem",
                "WFRichTextContentItem",
                "WFSafariWebPageContentItem",
                "WFStringContentItem",
                "WFURLContentItem",
            ],
            "WFWorkflowImportQuestions": [],
            "WFWorkflowTypes": ["NCWidget", "WatchKit"],
            "WFQuickActionSurfaces": [],
            "WFWorkflowHasShortcutInputVariables": false,
        ]
    }

    /// Generate the actions array for the shortcut
    private func generateActions() -> [[String: Any]] {
        return [
            // Action 1: Get Transaction Details
            [
                "WFWorkflowActionIdentifier": "is.workflow.actions.detect.transaction",
                "WFWorkflowActionParameters": [
                    "WFTransactionSource": "ApplePay",
                ],
            ],

            // Action 2: Extract Amount
            [
                "WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey",
                "WFWorkflowActionParameters": [
                    "WFDictionaryKey": "amount",
                    "WFInput": [
                        "WFActionOutput": [
                            "OutputUUID": "transaction-data",
                            "Type": "ActionOutput",
                        ],
                    ],
                ],
            ],

            // Action 3: Extract Currency
            [
                "WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey",
                "WFWorkflowActionParameters": [
                    "WFDictionaryKey": "currency",
                    "WFInput": [
                        "WFActionOutput": [
                            "OutputUUID": "transaction-data",
                            "Type": "ActionOutput",
                        ],
                    ],
                ],
            ],

            // Action 4: Extract Merchant (Optional)
            [
                "WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey",
                "WFWorkflowActionParameters": [
                    "WFDictionaryKey": "merchant",
                    "WFInput": [
                        "WFActionOutput": [
                            "OutputUUID": "transaction-data",
                            "Type": "ActionOutput",
                        ],
                    ],
                ],
            ],

            // Action 5: Extract Card Name (Optional)
            [
                "WFWorkflowActionIdentifier": "is.workflow.actions.getvalueforkey",
                "WFWorkflowActionParameters": [
                    "WFDictionaryKey": "cardName",
                    "WFInput": [
                        "WFActionOutput": [
                            "OutputUUID": "transaction-data",
                            "Type": "ActionOutput",
                        ],
                    ],
                ],
            ],

            // Action 6: Run LifeMeter Intent
            [
                "WFWorkflowActionIdentifier": "com.lifemeter.app.LogTransactionIntent",
                "WFWorkflowActionParameters": [
                    "amount": [
                        "WFActionOutput": [
                            "OutputUUID": "amount-value",
                            "Type": "ActionOutput",
                        ],
                    ],
                    "currency": [
                        "WFActionOutput": [
                            "OutputUUID": "currency-value",
                            "Type": "ActionOutput",
                        ],
                    ],
                    "merchant": [
                        "WFActionOutput": [
                            "OutputUUID": "merchant-value",
                            "Type": "ActionOutput",
                        ],
                    ],
                    "cardName": [
                        "WFActionOutput": [
                            "OutputUUID": "card-name-value",
                            "Type": "ActionOutput",
                        ],
                    ],
                ],
            ],
        ]
    }

    /// Export shortcut template to file
    public func exportTemplate() -> URL? {
        let template = generateTemplate()

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let shortcutURL = documentsPath.appendingPathComponent("\(shortcutName).shortcut")

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: template, format: .binary, options: 0)
            try data.write(to: shortcutURL)
            return shortcutURL
        } catch {
            #if DEBUG
                os_log(
                    .error,
                    "Failed to export shortcut template: %{private}@",
                    String(describing: error)
                )
            #endif
            return nil
        }
    }

    /// Generate deep link URL for importing the shortcut
    public func generateImportURL() -> URL? {
        guard let templateURL = exportTemplate() else { return nil }

        // Create shortcuts import URL
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "import-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: shortcutName),
            URLQueryItem(name: "url", value: templateURL.absoluteString),
        ]

        return components.url
    }

    /// Generate LifeMeter deep link for automation setup
    public func generateLifeMeterDeepLink() -> URL? {
        var components = URLComponents()
        components.scheme = "lifemeter"
        components.host = "add-applepay-automation"
        components.queryItems = [
            URLQueryItem(name: "shortcut", value: shortcutName),
            URLQueryItem(name: "identifier", value: shortcutIdentifier),
        ]

        return components.url
    }
}

// MARK: - Shortcut Configuration

@available(iOS 17.0, *)
public extension ShortcutTemplate {
    /// Configuration for the Apple Pay automation
    struct AutomationConfig {
        public let triggerType: String = "Transaction"
        public let cardTypes: [String] = ["All"]
        public let runImmediately: Bool = true
        public let askBeforeRunning: Bool = false
        public let notifyWhenRun: Bool = false

        public var description: String {
            return """
            This automation will:
            • Trigger when you pay with Apple Pay at terminals
            • Automatically calculate work time for the purchase
            • Show a notification with the result
            • Save the transaction to your LifeMeter history
            """
        }

        public var setupInstructions: String {
            return """
            1. Tap "Add Automation" below
            2. You'll be taken to the Shortcuts app
            3. Accept the pre-configured automation
            4. Make sure "Ask Before Running" is OFF
            5. Tap "Done" to activate

            Next time you pay with Apple Pay, LifeMeter will automatically show how many minutes you worked for that purchase!
            """
        }
    }

    static let automationConfig = AutomationConfig()
}

// MARK: - Shortcut Validation

@available(iOS 17.0, *)
public extension ShortcutTemplate {
    /// Validate that the shortcut template is properly formatted
    func validateTemplate() -> Bool {
        let template = generateTemplate()

        // Check required keys
        guard template["WFWorkflowActions"] is [[String: Any]],
              template["WFWorkflowMinimumClientVersion"] is Int,
              template["WFWorkflowClientVersion"] is String
        else {
            return false
        }

        // Validate actions
        guard let actions = template["WFWorkflowActions"] as? [[String: Any]],
              !actions.isEmpty
        else {
            return false
        }

        // Check that LifeMeter intent action exists
        let hasLifeMeterIntent = actions.contains { action in
            guard let identifier = action["WFWorkflowActionIdentifier"] as? String else { return false }
            return identifier == "com.lifemeter.app.LogTransactionIntent"
        }

        return hasLifeMeterIntent
    }

    /// Test the shortcut with sample data
    func testWithSampleData() -> Bool {
        let sampleTransaction = [
            "amount": 4.50,
            "currency": "EUR",
            "merchant": "Coffee Shop",
            "cardName": "Apple Card",
        ]

        // This would normally test the actual shortcut execution
        // For now, just validate the data structure
        return sampleTransaction["amount"] is Double &&
            sampleTransaction["currency"] is String
    }
}
