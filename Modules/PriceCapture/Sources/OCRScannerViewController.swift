import UIKit
import VisionKit
import Vision
import AVFoundation

// MARK: - OCR Scanner View Controller
@available(iOS 15.0, *)
public class OCRScannerViewController: UIViewController {
    
    // MARK: - Properties
    public weak var delegate: OCRScannerDelegate?
    
    private var documentCameraViewController: VNDocumentCameraViewController?
    private var isProcessingImage = false
    private var hasShownCameraPermissionAlert = false
    
    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !hasShownCameraPermissionAlert {
            checkCameraPermissionAndPresentScanner()
        }
    }
    
    // MARK: - Public Methods
    
    public func presentScanner() {
        checkCameraPermissionAndPresentScanner()
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add loading indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func checkCameraPermissionAndPresentScanner() {
        hasShownCameraPermissionAlert = true
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentDocumentScanner()
            
        case .notDetermined:
            showCameraPermissionPrePrompt()
            
        case .denied, .restricted:
            showCameraPermissionDeniedAlert()
            
        @unknown default:
            showCameraPermissionDeniedAlert()
        }
    }
    
    private func showCameraPermissionPrePrompt() {
        let alert = UIAlertController(
            title: "Camera Access",
            message: "LifeMeter needs camera access to scan prices from receipts. This helps you quickly convert prices to work time without manual entry.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Allow Camera", style: .default) { _ in
            self.requestCameraPermission()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.handleScanFailure(reason: "Camera access denied")
        })
        
        present(alert, animated: true)
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.presentDocumentScanner()
                } else {
                    self.showCameraPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func showCameraPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "To scan receipt prices, please enable camera access in Settings > LifeMeter > Camera.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
            self.handleScanFailure(reason: "Camera access denied")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.handleScanFailure(reason: "Camera access denied")
        })
        
        present(alert, animated: true)
    }
    
    private func presentDocumentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            showUnsupportedDeviceAlert()
            return
        }
        
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        present(scannerViewController, animated: true)
        
        documentCameraViewController = scannerViewController
    }
    
    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: "Scanner Not Available",
            message: "Document scanning is not supported on this device. Please enter the price manually.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.handleScanFailure(reason: "Scanner not supported")
        })
        
        present(alert, animated: true)
    }
    
    private func processScannedImage(_ image: UIImage) {
        guard !isProcessingImage else { return }
        isProcessingImage = true
        
        // Show processing indicator
        showProcessingIndicator()
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isProcessingImage = false
                self?.hideProcessingIndicator()
                
                if let error = error {
                    self?.handleScanFailure(reason: "Text recognition failed: \(error.localizedDescription)")
                    return
                }
                
                self?.handleTextRecognitionResults(request.results)
            }
        }
        
        // Configure for better price detection
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "it-IT"]
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessingImage = false
                    self.hideProcessingIndicator()
                    self.handleScanFailure(reason: "Image processing failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleTextRecognitionResults(_ results: [VNRecognizedTextObservation]?) {
        guard let results = results, !results.isEmpty else {
            handleScanFailure(reason: "No text detected in image")
            return
        }
        
        let detectedPrices = extractPricesFromResults(results)
        
        if detectedPrices.isEmpty {
            handleScanFailure(reason: "No price detected. Try again.")
        } else {
            // Use the highest confidence price
            let bestPrice = detectedPrices.max(by: { $0.confidence < $1.confidence })!
            handleScanSuccess(price: bestPrice.value, confidence: bestPrice.confidence)
        }
    }
    
    private func extractPricesFromResults(_ results: [VNRecognizedTextObservation]) -> [DetectedPrice] {
        var detectedPrices: [DetectedPrice] = []
        
        for observation in results {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // Extract prices using regex patterns
            let pricePatterns = [
                #"(\d+[.,]\d{2})"#,  // 12.34 or 12,34
                #"(\d+\.\d{2})"#,    // 12.34
                #"(\d+,\d{2})"#,     // 12,34
                #"(\d+)"#            // 12 (whole numbers)
            ]
            
            for pattern in pricePatterns {
                let regex = try? NSRegularExpression(pattern: pattern)
                let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let priceString = String(text[range])
                        
                        // Convert to double, handling both . and , as decimal separators
                        let normalizedString = priceString.replacingOccurrences(of: ",", with: ".")
                        
                        if let price = Double(normalizedString), price > 0 && price < 100000 {
                            detectedPrices.append(DetectedPrice(
                                value: price,
                                confidence: confidence,
                                originalText: priceString
                            ))
                        }
                    }
                }
            }
        }
        
        return detectedPrices
    }
    
    private func showProcessingIndicator() {
        // Add processing overlay
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.tag = 999
        overlay.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Scanning for prices..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        overlay.addSubview(activityIndicator)
        overlay.addSubview(label)
        view.addSubview(overlay)
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16)
        ])
    }
    
    private func hideProcessingIndicator() {
        view.subviews.first(where: { $0.tag == 999 })?.removeFromSuperview()
    }
    
    private func handleScanSuccess(price: Double, confidence: Float) {
        // Show success toast
        showSuccessToast(price: price)
        
        // Notify delegate
        delegate?.ocrScannerDidDetectPrice(price, confidence: confidence)
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.dismiss(animated: true)
        }
    }
    
    private func handleScanFailure(reason: String) {
        // Show failure alert
        let alert = UIAlertController(
            title: "Scan Failed",
            message: reason,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            // Automatically focus back on scan button
            self.presentDocumentScanner()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.delegate?.ocrScannerDidFail(with: OCRError.scanFailed(reason))
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showSuccessToast(price: Double) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = CurrencyManager.shared.selectedCurrency
        
        let formattedPrice = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        let message = "Price \(formattedPrice) scanned—converting now."
        
        let toast = ToastView(message: message, style: .success)
        toast.show(in: view)
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
@available(iOS 15.0, *)
extension OCRScannerViewController: VNDocumentCameraViewControllerDelegate {
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            // Process the first scanned page
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                self.processScannedImage(image)
            } else {
                self.handleScanFailure(reason: "No pages scanned")
            }
        }
    }
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.handleScanFailure(reason: error.localizedDescription)
        }
    }
    
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.delegate?.ocrScannerDidCancel()
            self.dismiss(animated: true)
        }
    }
}

// MARK: - OCR Scanner Delegate
public protocol OCRScannerDelegate: AnyObject {
    func ocrScannerDidDetectPrice(_ price: Double, confidence: Float)
    func ocrScannerDidFail(with error: OCRError)
    func ocrScannerDidCancel()
}

// MARK: - Detected Price
private struct DetectedPrice {
    let value: Double
    let confidence: Float
    let originalText: String
}

// MARK: - OCR Error
public enum OCRError: LocalizedError {
    case cameraNotAvailable
    case permissionDenied
    case scanFailed(String)
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission is required to scan receipts"
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .cameraNotAvailable:
            return "Please enter the price manually"
        case .permissionDenied:
            return "Enable camera access in Settings > LifeMeter > Camera"
        case .scanFailed, .processingFailed:
            return "Try scanning again or enter the price manually"
        }
    }
}

// MARK: - Toast View
private class ToastView: UIView {
    
    enum Style {
        case success
        case error
        case info
        
        var backgroundColor: UIColor {
            switch self {
            case .success: return .systemGreen
            case .error: return .systemRed
            case .info: return .systemBlue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    private let message: String
    private let style: Style
    
    init(message: String, style: Style) {
        self.message = message
        self.style = style
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = style.backgroundColor
        layer.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView(image: UIImage(systemName: style.icon))
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(label)
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func show(in parentView: UIView, duration: TimeInterval = 3.0) {
        parentView.addSubview(self)
        
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            leadingAnchor.constraint(greaterThanOrEqualTo: parentView.leadingAnchor, constant: 20),
            trailingAnchor.constraint(lessThanOrEqualTo: parentView.trailingAnchor, constant: -20)
        ])
        
        // Animate in
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -50)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.alpha = 1
            self.transform = .identity
        }
        
        // Animate out
        UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseInOut) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -50)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

