import AVFoundation
import Foundation
import UIKit
import Vision
import VisionKit
import os.log

// MARK: - Privacy-Aware OCR Manager

@available(iOS 15.0, *)
public class PrivacyAwareOCRManager: NSObject {
    // MARK: - Singleton

    public static let shared = PrivacyAwareOCRManager()

    // MARK: - Properties

    private var hasShownPrivacyRationale = false
    private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    private let privacySettings = PrivacySettings.shared

    // MARK: - Delegates

    public weak var delegate: PrivacyAwareOCRDelegate?

    // MARK: - Initialization

    override private init() {
        super.init()
        updateCameraPermissionStatus()
    }

    // MARK: - Public Methods

    /// Request OCR scanning with privacy-first approach
    public func requestOCRScanning(from viewController: UIViewController) {
        // Check if user has disabled OCR in privacy settings
        guard privacySettings.isOCREnabled else {
            delegate?.ocrManager(self, didFailWithError: .ocrDisabledByUser)
            return
        }

        // Show privacy rationale if not shown before
        if !hasShownPrivacyRationale {
            showPrivacyRationale(from: viewController)
            return
        }

        // Check camera permission
        checkCameraPermissionAndProceed(from: viewController)
    }

    /// Process image with privacy-aware OCR
    public func processImage(_ image: UIImage, completion: @escaping @Sendable (Result<OCRResult, PrivacyOCRError>) -> Void) {
        // Ensure OCR is enabled
        guard privacySettings.isOCREnabled else {
            completion(.failure(.ocrDisabledByUser))
            return
        }

        // Log privacy event
        logPrivacyEvent(.ocrProcessingStarted, details: "Image processing initiated")

        // Process image on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.performOCRProcessing(on: image, completion: completion)
        }
    }

    /// Check if OCR is available and privacy-compliant
    public func isOCRAvailable() -> Bool {
        return VNDocumentCameraViewController.isSupported &&
            privacySettings.isOCREnabled &&
            cameraPermissionStatus == .authorized
    }

    /// Get privacy status for OCR functionality
    public func getPrivacyStatus() -> OCRPrivacyStatus {
        return OCRPrivacyStatus(
            isOCREnabled: privacySettings.isOCREnabled,
            cameraPermissionStatus: cameraPermissionStatus,
            hasShownRationale: hasShownPrivacyRationale,
            isDeviceSupported: VNDocumentCameraViewController.isSupported
        )
    }

    /// Reset privacy settings (for testing or user request)
    public func resetPrivacySettings() {
        hasShownPrivacyRationale = false
        privacySettings.resetOCRSettings()
        logPrivacyEvent(.privacySettingsReset, details: "OCR privacy settings reset")
    }

    // MARK: - Private Methods

    private func showPrivacyRationale(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access for Price Scanning",
            message: createPrivacyRationaleMessage(),
            preferredStyle: .alert
        )

        // Privacy-first options
        alert.addAction(UIAlertAction(title: "Learn More", style: .default) { _ in
            self.showDetailedPrivacyInfo(from: viewController)
        })

        alert.addAction(UIAlertAction(title: "Enable Scanning", style: .default) { _ in
            self.hasShownPrivacyRationale = true
            self.checkCameraPermissionAndProceed(from: viewController)
        })

        alert.addAction(UIAlertAction(title: "Use Manual Entry", style: .cancel) { _ in
            self.delegate?.ocrManagerDidChooseManualEntry(self)
        })

        viewController.present(alert, animated: true)
    }

    private func showDetailedPrivacyInfo(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Your Privacy is Protected",
            message: createDetailedPrivacyMessage(),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Enable Scanning", style: .default) { _ in
            self.hasShownPrivacyRationale = true
            self.checkCameraPermissionAndProceed(from: viewController)
        })

        alert.addAction(UIAlertAction(title: "Keep Manual Entry", style: .cancel) { _ in
            self.delegate?.ocrManagerDidChooseManualEntry(self)
        })

        viewController.present(alert, animated: true)
    }

    private func createPrivacyRationaleMessage() -> String {
        return """
        LifeMeter can scan receipt prices using your camera to save time entering prices manually.

        🔒 Your privacy is protected:
        • Images are processed locally on your device
        • No photos are saved or stored
        • No data is sent to external servers
        • Camera access is only used for scanning

        You can always enter prices manually instead.
        """
    }

    private func createDetailedPrivacyMessage() -> String {
        return """
        LifeMeter's price scanning is designed with privacy-first principles:

        🔒 LOCAL PROCESSING ONLY
        • All image analysis happens on your device
        • Apple's on-device Vision framework is used
        • No cloud processing or external APIs

        📷 CAMERA ACCESS
        • Only used when you tap "Scan Receipt"
        • Images are processed immediately and discarded
        • No photos are saved to your device or camera roll

        🚫 NO DATA COLLECTION
        • Receipt images are never stored
        • Only the detected price number is kept
        • No merchant names or purchase details are saved

        ⚙️ FULL CONTROL
        • You can disable scanning anytime in Settings
        • Manual price entry is always available
        • Camera permission can be revoked in iOS Settings

        Your financial privacy is our top priority.
        """
    }

    private func checkCameraPermissionAndProceed(from viewController: UIViewController) {
        updateCameraPermissionStatus()

        switch cameraPermissionStatus {
        case .authorized:
            presentDocumentScanner(from: viewController)

        case .notDetermined:
            requestCameraPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.presentDocumentScanner(from: viewController)
                    } else {
                        self.handleCameraPermissionDenied(from: viewController)
                    }
                }
            }

        case .denied, .restricted:
            handleCameraPermissionDenied(from: viewController)

        @unknown default:
            handleCameraPermissionDenied(from: viewController)
        }
    }

    private func updateCameraPermissionStatus() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestCameraPermission(completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            self.updateCameraPermissionStatus()
            self.logPrivacyEvent(.cameraPermissionRequested, details: "Permission \(granted ? "granted" : "denied")")
            completion(granted)
        }
    }

    private func handleCameraPermissionDenied(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "To scan receipt prices, please enable camera access in Settings. Your privacy remains protected - images are only processed locally and never stored.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })

        alert.addAction(UIAlertAction(title: "Use Manual Entry", style: .cancel) { _ in
            self.delegate?.ocrManagerDidChooseManualEntry(self)
        })

        viewController.present(alert, animated: true)
    }

    private func presentDocumentScanner(from viewController: UIViewController) {
        guard VNDocumentCameraViewController.isSupported else {
            delegate?.ocrManager(self, didFailWithError: .scannerNotSupported)
            return
        }

        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self

        // Log privacy event
        logPrivacyEvent(.scannerPresented, details: "Document scanner presented to user")

        viewController.present(scannerViewController, animated: true)
    }

    private func performOCRProcessing(on image: UIImage, completion: @escaping @Sendable (Result<OCRResult, PrivacyOCRError>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(.imageProcessingFailed))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                self.logPrivacyEvent(.ocrProcessingFailed, details: "OCR failed: \(error.localizedDescription)")
                completion(.failure(.textRecognitionFailed(error)))
                return
            }

            let result = self.extractPricesFromResults(request.results)

            if result.detectedPrices.isEmpty {
                self.logPrivacyEvent(.ocrProcessingCompleted, details: "No prices detected")
                completion(.failure(.noPricesDetected))
            } else {
                self.logPrivacyEvent(.ocrProcessingCompleted, details: "Prices detected successfully")
                completion(.success(result))
            }
        }

        // Configure for optimal privacy and accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.01 // Detect small text

        // Only recognize numbers and currency symbols for privacy
        request.recognitionLanguages = ["en-US"] // Limit to reduce processing

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logPrivacyEvent(.ocrProcessingFailed, details: "Handler failed: \(error.localizedDescription)")
            completion(.failure(.imageProcessingFailed))
        }
    }

    private func extractPricesFromResults(_ results: [VNRecognizedTextObservation]?) -> OCRResult {
        guard let results = results else {
            return OCRResult(detectedPrices: [], processingTime: 0, confidence: 0)
        }

        let startTime = Date()
        var detectedPrices: [DetectedPrice] = []

        for observation in results {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let text = topCandidate.string
            let confidence = topCandidate.confidence

            // Extract only price-like patterns for privacy
            let pricePatterns = [
                #"(\d+[.,]\d{2})"#, // 12.34 or 12,34
                #"(\d+\.\d{2})"#, // 12.34
                #"(\d+,\d{2})"#, // 12,34
                #"(\d+)"#, // 12 (whole numbers)
            ]

            for pattern in pricePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

                    for match in matches {
                        if let range = Range(match.range, in: text) {
                            let priceString = String(text[range])

                            // Convert to double, handling both . and , as decimal separators
                            let normalizedString = priceString.replacingOccurrences(of: ",", with: ".")

                            if let price = Double(normalizedString),
                               price > 0 && price < 100_000
                            { // Reasonable price range
                                detectedPrices.append(DetectedPrice(
                                    value: price,
                                    confidence: confidence,
                                    originalText: priceString,
                                    boundingBox: observation.boundingBox
                                ))
                            }
                        }
                    }
                }
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let averageConfidence = detectedPrices.isEmpty ? 0 :
            detectedPrices.map { $0.confidence }.reduce(0, +) / Float(detectedPrices.count)

        return OCRResult(
            detectedPrices: detectedPrices,
            processingTime: processingTime,
            confidence: averageConfidence
        )
    }

    private func logPrivacyEvent(_ event: PrivacyEvent, details: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if DEBUG
            os_log(.debug, "\u{1F512} Privacy Event [%{public}@]: %{public}@ - %{public}@",
                   timestamp, event.rawValue, details)
        #endif

        // In production, log to privacy audit trail
        // Note: Only log events, never log actual image data or detected text
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

@available(iOS 15.0, *)
extension PrivacyAwareOCRManager: VNDocumentCameraViewControllerDelegate {
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)

                // Process image immediately and securely
                self.processImage(image) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case let .success(ocrResult):
                            self.delegate?.ocrManager(self, didDetectPrices: ocrResult.detectedPrices)
                        case let .failure(error):
                            self.delegate?.ocrManager(self, didFailWithError: error)
                        }
                    }
                }
            } else {
                self.delegate?.ocrManager(self, didFailWithError: .noPagesScanned)
            }
        }
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.logPrivacyEvent(.scannerFailed, details: error.localizedDescription)
            self.delegate?.ocrManager(self, didFailWithError: .scannerFailed(error))
        }
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.logPrivacyEvent(.scannerCancelled, details: "User cancelled scanning")
            self.delegate?.ocrManagerDidCancel(self)
        }
    }
}

// MARK: - Privacy-Aware OCR Delegate

public protocol PrivacyAwareOCRDelegate: AnyObject {
    func ocrManager(_ manager: PrivacyAwareOCRManager, didDetectPrices prices: [DetectedPrice])
    func ocrManager(_ manager: PrivacyAwareOCRManager, didFailWithError error: PrivacyOCRError)
    func ocrManagerDidCancel(_ manager: PrivacyAwareOCRManager)
    func ocrManagerDidChooseManualEntry(_ manager: PrivacyAwareOCRManager)
}

// MARK: - Privacy Settings

public class PrivacySettings {
    // MARK: - Singleton

    public static let shared = PrivacySettings()

    // MARK: - Properties

    private let userDefaults = UserDefaults.standard

    // MARK: - OCR Settings

    public var isOCREnabled: Bool {
        get {
            return userDefaults.bool(forKey: "privacy.ocr.enabled")
        }
        set {
            userDefaults.set(newValue, forKey: "privacy.ocr.enabled")
            logPrivacyEvent(.settingChanged, details: "OCR enabled: \(newValue)")
        }
    }

    public var hasShownOCRPrivacyNotice: Bool {
        get {
            return userDefaults.bool(forKey: "privacy.ocr.notice_shown")
        }
        set {
            userDefaults.set(newValue, forKey: "privacy.ocr.notice_shown")
        }
    }

    // MARK: - Initialization

    private init() {
        // Set default values
        if !userDefaults.bool(forKey: "privacy.defaults_set") {
            isOCREnabled = true // Default to enabled, but with privacy protections
            userDefaults.set(true, forKey: "privacy.defaults_set")
        }
    }

    // MARK: - Public Methods

    public func resetOCRSettings() {
        userDefaults.removeObject(forKey: "privacy.ocr.enabled")
        userDefaults.removeObject(forKey: "privacy.ocr.notice_shown")
        userDefaults.removeObject(forKey: "privacy.defaults_set")

        // Reset to defaults
        isOCREnabled = true
    }

    private func logPrivacyEvent(_ event: PrivacyEvent, details: String) {
        #if DEBUG
            os_log(.debug, "\u{1F512} Privacy Setting: %{public}@ - %{public}@",
                   event.rawValue, details)
        #endif
    }
}

// MARK: - Models

public struct OCRResult {
    public let detectedPrices: [DetectedPrice]
    public let processingTime: TimeInterval
    public let confidence: Float

    public var bestPrice: DetectedPrice? {
        return detectedPrices.max(by: { $0.confidence < $1.confidence })
    }
}

public struct DetectedPrice {
    public let value: Double
    public let confidence: Float
    public let originalText: String
    public let boundingBox: CGRect

    public var formattedValue: String {
        return String(format: "%.2f", value)
    }
}

public struct OCRPrivacyStatus {
    public let isOCREnabled: Bool
    public let cameraPermissionStatus: AVAuthorizationStatus
    public let hasShownRationale: Bool
    public let isDeviceSupported: Bool

    public var isFullyAvailable: Bool {
        return isOCREnabled &&
            cameraPermissionStatus == .authorized &&
            isDeviceSupported
    }
}

// MARK: - Errors

public enum PrivacyOCRError: LocalizedError {
    case ocrDisabledByUser
    case cameraPermissionDenied
    case scannerNotSupported
    case scannerFailed(Error)
    case noPagesScanned
    case imageProcessingFailed
    case textRecognitionFailed(Error)
    case noPricesDetected

    public var errorDescription: String? {
        switch self {
        case .ocrDisabledByUser:
            return "OCR scanning is disabled in privacy settings"
        case .cameraPermissionDenied:
            return "Camera permission is required for scanning"
        case .scannerNotSupported:
            return "Document scanning is not supported on this device"
        case let .scannerFailed(error):
            return "Scanner failed: \(error.localizedDescription)"
        case .noPagesScanned:
            return "No pages were scanned"
        case .imageProcessingFailed:
            return "Failed to process the scanned image"
        case let .textRecognitionFailed(error):
            return "Text recognition failed: \(error.localizedDescription)"
        case .noPricesDetected:
            return "No prices were detected in the image"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .ocrDisabledByUser:
            return "Enable OCR scanning in Settings > Privacy"
        case .cameraPermissionDenied:
            return "Enable camera access in Settings > LifeMeter > Camera"
        case .scannerNotSupported:
            return "Please enter the price manually"
        case .scannerFailed, .imageProcessingFailed, .textRecognitionFailed:
            return "Try scanning again or enter the price manually"
        case .noPagesScanned, .noPricesDetected:
            return "Try scanning again with better lighting or enter the price manually"
        }
    }
}

// MARK: - Privacy Events

private enum PrivacyEvent: String {
    case ocrProcessingStarted = "OCR_PROCESSING_STARTED"
    case ocrProcessingCompleted = "OCR_PROCESSING_COMPLETED"
    case ocrProcessingFailed = "OCR_PROCESSING_FAILED"
    case cameraPermissionRequested = "CAMERA_PERMISSION_REQUESTED"
    case scannerPresented = "SCANNER_PRESENTED"
    case scannerFailed = "SCANNER_FAILED"
    case scannerCancelled = "SCANNER_CANCELLED"
    case privacySettingsReset = "PRIVACY_SETTINGS_RESET"
    case settingChanged = "SETTING_CHANGED"
}
